This control repo includes the code to fulfil PoC requirements for client.

To get started with the repo, follow these steps:

1) Make sure you have a github.com account
2) Fork the https://github.com/chrismatteson/clientpoc1 repo by navigating to that page, then clicking the "fork" button at the top right and choosing to fork to your namespace
3) Create a folder at /etc/puppetlabs/puppetserver/ssh on your master
4) Follow these steps to create a deploy key: https://developer.github.com/guides/managing-deploy-keys/#setup-2
 - When it asks you the path to create the key, enter /etc/puppetlabs/puppetserver/id-control_repo.rsa
 - The public key you need to paste into the web portal will be created at /etc/puppetlabs/puppetserver/id-control_repo.rsa.pub make sure to select "Allow write access"
 - Change both of those files to have owner and group of "pe-puppet"
5) Login to the console of your Puppet Enterprise Manager.  Go to classification, then open the "PE Master" Group.  On the classes tab find the "puppet_enterprise::profile::master" class.
 - Add the following parameters:
  - code_manager_auto_configure: false
  - r10k_remote: git@github.com/<username>/clientpoc1.git (replace <username> with your github username)
  - r10k_private_key: /etc/puppetlabs/puppetserver/ssh/id-control_repo.rsa
6) Run "puppet agent -t" on the master
7) Run "r10k deploy environment -p" on the master
8) Copy the hiera.yaml to /etc/puppetlabs/puppet/hiera.yaml then run "service pe-puppetserver restart"
