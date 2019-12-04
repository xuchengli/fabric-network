#!/bin/bash

docker-compose -f docker-compose.yml down
rm -rf org0

docker-compose -f docker-compose.yml up -d ca.example.com
docker ps -a

sleep 5

export FABRIC_CA_CLIENT_HOME=${PWD}/org0/ca/admin
${PWD}/bin/fabric-ca-client enroll -u http://admin:adminpw@localhost:7054
${PWD}/bin/fabric-ca-client register --id.name orderer-org0 --id.secret ordererpw --id.type orderer
${PWD}/bin/fabric-ca-client register --id.name admin-org0 --id.secret adminpw --id.type admin --id.attrs "hf.Registrar.Roles=client,hf.Registrar.Attributes=*,hf.Revoker=true,hf.GenCRL=true,admin=true:ecert,abac.init=true:ecert"
