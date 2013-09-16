
require 'yaml'

#
# Automatically loads the asset file relevant to the given spec.
#
def load_asset_file(spec_filename)

  #If we weren't provided with a filename, automatically produce one from the currently
  #running spec's name
  filename = spec_filename.gsub(/spec.rb$/, "assets.yaml")
  
  #And parse the YAML file.
  let(:assets) { YAML.load(File.open(filename)) }

end
