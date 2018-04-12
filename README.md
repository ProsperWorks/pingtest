# pingtest

Scripting to measure latency between various clouds to various
services.

Short instructions are:
1. Set up nodes in EC2 and GCP as described in Makefile.
2. Add or remove EC2_TEST and GCP_TEST calls as appropriate to the nodes you created.
3. Delete the pingtest-local and pingtest-ali-integration and pingtest-onebox-* stuff which will be too idiosyncratic and ProsperWorksish to be useful to you.
4. Run `make hostname` to accept the fingerprint for all the nodes and test `ssh`ing to each.
5. Run `make setup -j` to install all the requisite software in each node in parallel.  Should take just a minute.
6. Create an accessible Redis instance and Postgres instance somewhere.
7. Edit all the places in Makefile which include `heroku config` to be the connection strings to your Redis and your Postgres.
8. Run `make pingtest -j` to run all the testing in parallel.  Should take just a couple minutes.