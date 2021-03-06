# frozen_string_literal: true

module EcsDeployCli
  module Runners
    class Setup < Base
      REQUIRED_ECS_ROLES = {
        'ecsInstanceRole' => 'https://docs.aws.amazon.com/batch/latest/userguide/instance_IAM_role.html',
        'ecsTaskExecutionRole' => 'https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_execution_IAM_role.html'
      }.freeze
      class SetupError < StandardError; end

      def run!
        services, resolved_tasks, _, cluster_options = @parser.resolve

        ensure_ecs_roles_exists!

        setup_cluster! cluster_options
        setup_services! services, resolved_tasks: resolved_tasks
      rescue SetupError => e
        EcsDeployCli.logger.info e.message
      end

      private

      def setup_cluster!(cluster_options)
        if cluster_exists?
          EcsDeployCli.logger.info 'Cluster already created, skipping.'
          return
        end

        EcsDeployCli.logger.info "Creating cluster #{config[:cluster]}..."

        create_keypair_if_required! cluster_options
        params = create_params(cluster_options)

        ecs_client.create_cluster(
          cluster_name: config[:cluster]
        )
        EcsDeployCli.logger.info 'Cluster created, now running cloudformation...'

        stack_name = "EC2ContainerService-#{config[:cluster]}"

        cf_client.create_stack(
          stack_name: stack_name,
          template_body: File.read(File.join(__dir__, '..', 'cloudformation', 'default.yml')),
          on_failure: 'ROLLBACK',
          parameters: format_cloudformation_params(params)
        )

        cf_client.wait_until(:stack_create_complete, { stack_name: stack_name }, delay: 30, max_attempts: 120)
        EcsDeployCli.logger.info "Cluster #{config[:cluster]} created! 🎉"
      end

      def setup_services!(services, resolved_tasks:)
        services.each do |service_name, service_definition|
          existing_services = ecs_client.describe_services(cluster: config[:cluster], services: [service_name]).to_h[:services].select { |s| s[:status] != 'INACTIVE' }
          if existing_services.any?
            EcsDeployCli.logger.info "Service #{service_name} already created, skipping."
            next
          end

          EcsDeployCli.logger.info "Creating service #{service_name}..."
          task_definition = _update_task resolved_tasks[service_definition.options[:task]]
          task_name = "#{task_definition[:family]}:#{task_definition[:revision]}"

          ecs_client.create_service(
            cluster: config[:cluster],
            desired_count: 1, # FIXME: this should be a parameter
            load_balancers: service_definition.as_definition(task_definition)[:load_balancers],
            service_name: service_name,
            task_definition: task_name
          )
          EcsDeployCli.logger.info "Service #{service_name} created!"
        end
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

      def cluster_exists?
        clusters = ecs_client.describe_clusters(clusters: [config[:cluster]]).to_h[:clusters]

        clusters.count { |c| c[:status] != 'INACTIVE' } == 1
      end

      def ensure_ecs_roles_exists!
        REQUIRED_ECS_ROLES.each do |role_name, link|
          iam_client.get_role(role_name: role_name).to_h
        rescue Aws::IAM::Errors::NoSuchEntity
          raise SetupError, "IAM Role #{role_name} does not exist. Please create it: #{link}."
        end
      end

      def create_keypair_if_required!(cluster_options)
        ec2_client.describe_key_pairs(key_names: [cluster_options[:keypair_name]]).to_h[:key_pairs]
      rescue Aws::EC2::Errors::InvalidKeyPairNotFound
        EcsDeployCli.logger.info "Keypair \"#{cluster_options[:keypair_name]}\" not found, creating it..."
        key_material = ec2_client.create_key_pair(key_name: cluster_options[:keypair_name]).to_h[:key_material]
        File.write("#{cluster_options[:keypair_name]}.pem", key_material)
        EcsDeployCli.logger.info "Created PEM file at #{Dir.pwd}/#{cluster_options[:keypair_name]}.pem"
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
