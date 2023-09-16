# Minecraft on AWS

This is terraform implementation of [Minecraft ondemand](https://github.com/doctorray117/minecraft-ondemand).

## Motivations

The original motivation was to reduce the number of hosted zones required from 2 to 1, reducing the fixed cost of leaving the resources running. However the AWS CDK did not allow modifying existing resources, in particular attaching a query log group to an existing Hosted Zone.

Personally I also find declarative IaC to be easier to understand than the way the AWS CDK works.

While reimplementing the IaC template, I also figured to modify it to make managing multiple servers possible and make managing mods easier.

## Notes

### Module

Task needs:
- task role for the containerized applications to call AWS APIs
https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task-iam-roles.html
 - For Watchdog to:
    - Get the ENI for the task
    - Get the public IP of the task

These require `ec2:DescribeNetworkInterfaces` 

    - Update the DNS A-record to point to the public IP of the task.

```
  "route53:GetHostedZone",
  "route53:ChangeResourceRecordSets",
  "route53:ListResourceRecordSets"
```
    - Reduce the desired number of tasks for the service.
- task execution role to send container logs to CloudWatch Logs using the `awslogs` log driver.
https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_execution_IAM_role.html