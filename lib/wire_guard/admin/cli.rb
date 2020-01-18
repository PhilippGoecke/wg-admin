# frozen_string_literal: true

require 'thor'
require 'ipaddr'

require 'wire_guard/admin/repository'
require 'wire_guard/admin/client'
require 'wire_guard/admin/server'
require 'wire_guard/admin/templates/client'
require 'wire_guard/admin/templates/server'

module WireGuard
  module Admin
    #
    # Provides all the commands
    #
    # rubocop:disable Metrics/ClassLength
    class CLI < Thor
      class << self
        def exit_on_failure?
          true
        end

        def default_network
          ENV['WG_ADMIN_NETWORK']
        end

        def path
          ENV['WG_ADMIN_STORE'] || File.expand_path('~/.wg-admin.pstore')
        end

        def repository
          @repository ||= Repository.new(path)
        end
      end

      class_option :verbose, type: :boolean, aliases: '-v'
      package_name 'wg-admin is an opinionated tool to administer WireGuard configuration.

Available'

      desc 'list-networks', 'Lists all known networks'
      long_desc 'List the networks in the configuration database.'
      def list_networks
        if options[:verbose]
          warn "Using database #{repository.path}"
          warn 'No networks defined.' if repository.networks.empty?
        end

        repository.networks.each do |network|
          puts "  #{network}/#{network.prefix}"
        end
      end

      # rubocop:disable Metrics/AbcSize
      desc 'add-network NETWORK', 'Adds a new network'
      long_desc 'Adds a new network to the configuration database.'
      def add_network(network)
        warn "Using database #{repository.path}" if options[:verbose]
        repository.add_network(IPAddr.new(network))
        warn "Network #{repository.network} was successfully added." if options[:verbose]
      rescue Repository::NetworkAlreadyExists
        warn "Error: #{$ERROR_INFO.message}"
      end

      desc 'list-peers', 'Lists all peers'
      long_desc 'For a given network, lists all peers in the configuration database.'
      method_option :network, desc: 'network', aliases: '-n', default: default_network
      def list_peers
        if options[:verbose]
          warn "Using database #{repository.path}"
          warn "No peers in network #{network}." if repository.networks.empty?
        end
        repository.peers(network).each do |peer|
          puts "  #{peer}"
        end
      rescue StandardError
        warn "Error: #{$ERROR_INFO.message}"
      end

      # rubocop:disable Metrics/CyclomaticComplexity, Metrics/MethodLength
      desc 'add-server NAME', 'Adds a new server with the given public DNS NAME'
      long_desc 'Adds a new server to the configuration database.'
      method_option :network, desc: 'network', aliases: '-n', default: default_network
      method_option :ip, desc: 'the (private) IP address of the new server (within the VPN)', aliases: '-i', required: false
      method_option :port, desc: 'port to listen on', aliases: '-p', required: false
      method_option :allowed_ips, desc: 'The range of allowed IP addresses that this server is routing', aliases: '-a', required: false
      method_option :device, desc: 'The network device used for forwarding traffic', aliases: '-d', required: false
      def add_server(name)
        warn "Using database #{repository.path}" if options[:verbose]
        server = Server.new(name: name, ip: ip, allowed_ips: options[:allowed_ips] || repository.find_network(network))
        server.device = options[:device] if options[:device]
        server.port = options[:port] if options[:port]
        repository.add_peer(network, server)
        if options[:verbose]
          warn 'New server was successfully added:'
          warn ''
          warn server
        end
      rescue StandardError
        warn "Error: #{$ERROR_INFO.message}"
      end
      # rubocop:enable Metrics/CyclomaticComplexity, Metrics/MethodLength

      desc 'add-client NAME', 'Adds a new client with the given NAME'
      long_desc 'Adds a new client to the configuration database.'
      method_option :network, desc: 'network', aliases: '-n', default: default_network
      method_option :ip, desc: 'the IP address of the new client', aliases: '-i', required: false
      def add_client(name)
        warn "Using database #{repository.path}" if options[:verbose]
        client = Client.new(name: name, ip: ip)
        repository.add_peer(network, client)
        if options[:verbose]
          warn 'New client was successfully added:'
          warn ''
          warn client
        end
      rescue StandardError
        warn "Error: #{$ERROR_INFO.message}"
      end

      # rubocop:disable Metrics/MethodLength
      desc 'config', 'Show the configuration of a peer'
      long_desc 'Prints the configuration for a peer to STDOUT.'
      method_option :network, desc: 'network', aliases: '-n', default: default_network
      def config(name)
        warn "Using database #{repository.path}" if options[:verbose]
        peer = repository.find_peer(network, name)

        case peer
        when Server
          puts Templates::Server.new(peer, repository.clients(network)).render
        when Client
          puts Templates::Client.new(peer, repository.servers(network)).render
        else
          raise "No template defined for #{peer}"
        end
      rescue StandardError
        warn "Error: #{$ERROR_INFO.message}"
      end
      # rubocop:enable Metrics/MethodLength
      # rubocop:enable Metrics/AbcSize

      private

      def repository
        self.class.repository
      end

      def ip
        if options[:ip]
          IPAddr.new(options[:ip])
        else
          repository.next_address(network)
        end
      end

      def network
        IPAddr.new(options[:network])
      end
    end
    # rubocop:enable Metrics/ClassLength
  end
end