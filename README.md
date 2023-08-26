# Minecraft on AWS

This is terraform implementation of [Minecraft ondemand](https://github.com/doctorray117/minecraft-ondemand).

## Motivations

The original motivation was to reduce the number of hosted zones required from 2 to 1, reducing the fixed cost of leaving the resources running. However the AWS CDK did not allow modifying existing resources, in particular attaching a query log group to an existing Hosted Zone.

Personally I also find declarative IaC to be easier to understand than the way the AWS CDK works.

While reimplementing the IaC template, I also figured to modify it to make managing multiple servers possible and make managing mods easier.