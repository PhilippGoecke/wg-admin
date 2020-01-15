require 'wireguard/admin/repository'
require 'tempfile'

describe Wireguard::Admin::Repository do
  subject(:repo) { described_class.new( Tempfile.new('wg-admin unit test').path ) }

  context 'no network was added' do
    it 'has an empty list of networks' do
      expect(repo.networks).to be_empty
    end

    it 'does not accept a new peer' do
      expect { repo.add_peer('10.1.2.0', 'somebody') }.to raise_error(Wireguard::Admin::Repository::UnknownNetwork)
    end

    it 'does not provide the next address' do
      expect { repo.next_address('10.1.2.0') }.to raise_error(Wireguard::Admin::Repository::UnknownNetwork)
    end
  end

  context 'network 10.1.2.0/24 was added' do
    before { repo.add_network('10.1.2.0/24') }

    it 'lists the existing network' do
      expect(repo.networks).to include('10.1.2.0/24')
    end

    it 'accepts a new peer within the known network' do
      expect {repo.add_peer('10.1.2.0/24', 'somebody') }.to_not raise_error
    end

    it 'does provide the next address' do
      expect(repo.next_address('10.1.2.0/24')).to eq('10.1.2.1')
    end
  end
end
