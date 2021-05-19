# frozen_string_literal: true

module EcsDeployCli
  module DSL
    class Cluster
      include AutoOptions

      allowed_options :instances_count, :instance_type, :ebs_volume_size, :keypair_name

      def initialize(name, config)
        @config = config
        _options[:name] = name.to_s
      end

      def vpc(id = nil, &block)
        @vpc = VPC.new(id)
        @vpc.instance_exec(&block)
      end

      def as_definition
        {
          instances_count: 1,

          device_name: '/dev/xvda',
          ebs_volume_size: 22,
          ebs_volume_type: 'gp2',

          root_device_name: '/dev/xvdcz',
          root_ebs_volume_size: 30,

          vpc: @vpc&.as_definition
        }.merge(_options)
      end

      class VPC
        include AutoOptions
        allowed_options :cidr, :subnet1, :subnet2, :subnet3

        def initialize(id)
          _options[:id] = id
        end

        def availability_zones(*values)
          _options[:availability_zones] = values.join(',')
        end

        def subnet_ids(*values)
          _options[:subnet_ids] = values.join(',')
        end

        def as_definition
          validate! if _options[:id]

          {
            cidr: '10.0.0.0/16',
            subnet1: '10.0.0.0/24',
            subnet2: '10.0.1.0/24',
            subnet3: '10.0.2.0/24'
          }.merge(_options)
        end

        def validate!
          [
            :subnet1, :subnet_ids, :availability_zones
          ].each { |key| raise "Missing required parameter #{key}" unless _options[key] }
        end
      end
    end
  end
end
