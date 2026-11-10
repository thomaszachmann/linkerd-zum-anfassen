#!/usr/bin/env ruby
# Prüft alle Manifeste unter labs/ gegen die OpenAPI-Schemas der CRDs.
# Kein Cluster nötig. Aufruf: ruby pruefung/pruefe-labs.rb <refdata-Verzeichnis>
# Erwartet <refdata>/crds/*.yaml (linkerd-crds-Chart) und <refdata>/gw/standard-install.yaml.
require 'yaml'

ref = ARGV[0] or abort('Aufruf: pruefe-labs.rb <refdata-Verzeichnis>')
schemas = {}
sources = Dir["#{ref}/crds/*.yaml"].reject { |f| f =~ /values|gateway\.networking/ } + ["#{ref}/gw/standard-install.yaml"]
sources.each do |file|
  text = File.read(file).lines.reject { |l| l =~ /^\s*\{\{.*\}\}\s*$/ || l =~ /:\s*\{\{.*\}\}/ }.join
  YAML.load_stream(text).compact.each do |doc|
    next unless doc['kind'] == 'CustomResourceDefinition'
    doc['spec']['versions'].each do |v|
      next unless v['served']
      schemas["#{doc['spec']['group']}/#{v['name']}/#{doc['spec']['names']['kind']}"] =
        { schema: v['schema']['openAPIV3Schema'], deprecated: v['deprecated'] }
    end
  end
end

def check(val, sch, path, errs)
  return if sch.nil?
  case sch['type']
  when 'object'
    return errs << "#{path}: Objekt erwartet" unless val.is_a?(Hash)
    (sch['required'] || []).each { |k| errs << "#{path}.#{k}: Pflichtfeld fehlt" unless val.key?(k) }
    props = sch['properties']
    val.each do |k, v|
      next if path !~ /\./ && %w[apiVersion kind metadata].include?(k)
      if props&.key?(k) then check(v, props[k], "#{path}.#{k}", errs)
      elsif sch['additionalProperties'].is_a?(Hash) then check(v, sch['additionalProperties'], "#{path}.#{k}", errs)
      elsif props && !sch['x-kubernetes-preserve-unknown-fields'] then errs << "#{path}.#{k}: unbekanntes Feld"
      end
    end
  when 'array'
    return errs << "#{path}: Liste erwartet" unless val.is_a?(Array)
    val.each_with_index { |v, i| check(v, sch['items'], "#{path}[#{i}]", errs) }
  when 'string'
    errs << "#{path}: String erwartet" unless val.is_a?(String)
    errs << "#{path}: Wert #{val.inspect} passt nicht zu #{sch['pattern']}" if val.is_a?(String) && sch['pattern'] && !Regexp.new(sch['pattern']).match?(val)
  when 'integer'
    errs << "#{path}: Ganzzahl erwartet" unless val.is_a?(Integer)
  end
  errs << "#{path}: #{val.inspect} nicht in #{sch['enum']}" if sch['enum'] && !sch['enum'].include?(val)
  if sch['oneOf']
    hits = sch['oneOf'].count { |o| (o['required'] || []).all? { |k| val.is_a?(Hash) && val.key?(k) } }
    errs << "#{path}: oneOf nicht erfüllt (#{hits} Treffer)" unless hits == 1
  end
end

total = crs = failed = 0
Dir['labs/**/*.yaml'].sort.each do |f|
  YAML.load_stream(File.read(f)).compact.each do |doc|
    total += 1
    errs = []
    errs << 'apiVersion/kind/metadata.name fehlt' unless doc['apiVersion'] && doc['kind'] && (doc['metadata'] || {})['name'] || doc['kind'] == 'Cluster'
    key = "#{doc['apiVersion']}/#{doc['kind']}"
    if doc['apiVersion'] =~ /linkerd\.io|gateway\.networking/
      crs += 1
      s = schemas[key]
      if s.nil? then errs << "keine ausgelieferte CRD-Version für #{key}"
      else
        errs << 'Version ist deprecated' if s[:deprecated]
        check(doc, s[:schema], doc['kind'], errs)
      end
    end
    status = errs.empty? ? 'OK  ' : 'FEHL'
    failed += 1 unless errs.empty?
    puts "#{status} #{f} #{doc['kind']}/#{(doc['metadata'] || {})['name']}"
    errs.each { |e| puts "     #{e}" }
  end
end
puts "#{total} Dokumente, davon #{crs} gegen CRD-Schemas geprüft, #{failed} fehlerhaft"
exit(failed.zero? ? 0 : 1)
