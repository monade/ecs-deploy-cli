# frozen_string_literal: true

module EcsDeployCli
  module Runners
    class Setup < Base
      def run!
        _, _, _, cluster_options = @parser.resolve

        params = create_params(cluster_options)

        ecs_client.create_cluster(
          cluster_name: config[:cluster]
        )

        stack_name = "EC2ContainerService-#{config[:cluster]}"

        cf_client.create_stack(
          stack_name: stack_name,
          template_body: File.read(File.join(__dir__, '..', 'cloudformation', 'default.yml')),
          on_failure: 'ROLLBACK',
          parameters: format_cloudformation_params(params)
        )

        cf_client.wait_until(:stack_create_complete, { stack_name: stack_name }, delay: 30, max_attempts: 120)
      end

      def create_params(cluster_options)
        raise ArgumentError, 'Missing vpc configuration' unless cluster_options[:vpc]

        {
          'AsgMaxSize' => cluster_options[:instances_count],
          'AutoAssignPublicIp' => 'INHERIT',
          'ConfigureDataVolume' => false,
          'ConfigureRootVolume' => true,
          'DeviceName' => cluster_options[:device_name],
          'EbsVolumeSize' => cluster_options[:ebs_volume_size],
          'EbsVolumeType' => cluster_options[:ebs_volume_type],
          'EcsAmiId' => load_ami_id,
          'EcsClusterName' => config[:cluster],
          'EcsEndpoint' => nil,
          'EcsInstanceType' => cluster_options[:instance_type],
          'IamRoleInstanceProfile' => "arn:aws:iam::#{config[:aws_profile_id]}:instance-profile/ecsInstanceRole",
          'IamSpotFleetRoleArn' => nil,
          'IsWindows' => false,
          'KeyName' => cluster_options[:keypair_name],
          'RootDeviceName' => cluster_options[:root_device_name],
          'RootEbsVolumeSize' => cluster_options[:root_ebs_volume_size],

          ##### TODO: Implement this feature
          'SecurityGroupId' => nil,
          'SecurityIngressCidrIp' => '0.0.0.0/0',
          'SecurityIngressFromPort' => 80,
          'SecurityIngressToPort' =>	80,
          #####

          ##### TODO: Implement this feature
          'SpotAllocationStrategy' =>	'diversified',
          'SpotPrice' => nil,
          'UseSpot' =>	false,
          #####

          'UserData' => "#!/bin/bash\necho ECS_CLUSTER=#{config[:cluster]} >> /etc/ecs/ecs.config;echo ECS_BACKEND_HOST= >> /etc/ecs/ecs.config;",
          'VpcAvailabilityZones' => cluster_options.dig(:vpc, :availability_zones),
          'VpcCidr' => cluster_options.dig(:vpc, :cidr),
          'SubnetCidr1' => cluster_options.dig(:vpc, :subnet1),
          'SubnetCidr2' => cluster_options.dig(:vpc, :subnet2),
          'SubnetCidr3' => cluster_options.dig(:vpc, :subnet3),

          'VpcId' => cluster_options.dig(:vpc, :id),
          'SubnetIds' => cluster_options.dig(:vpc, :subnet_ids)
        }
      end

      def format_cloudformation_params(params)
        params.map { |k, v| { parameter_key: k, parameter_value: v.to_s } }
      end

      def load_ami_id
        ami_data = ssm_client.get_parameter(
          name: '/aws/service/ecs/optimized-ami/amazon-linux-2/recommended'
        ).to_h[:parameter]

        ami_details = JSON.parse(ami_data[:value]).with_indifferent_access

        ami_details[:image_id]
      end
    end
  end
end
