require File.expand_path('../../spec_helper', __FILE__)

module Pod
  describe Command::Jsource do
    describe 'CLAide' do
      it 'registers it self' do
        Command.parse(%w{ jsource }).should.be.instance_of Command::Jsource
      end
    end
  end
end

