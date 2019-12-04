#!/bin/bash

docker-compose -f docker-compose.yml down
rm -rf org0 org1 config

docker-compose -f docker-compose.yml up -d ca.example.com
docker ps -a

sleep 5

# 注册peer和orderer身份
export FABRIC_CA_CLIENT_HOME=${PWD}/org0/ca/admin
${PWD}/bin/fabric-ca-client enroll -u http://admin:adminpw@localhost:7054
${PWD}/bin/fabric-ca-client register --id.name orderer-org0 --id.secret ordererpw --id.type orderer
${PWD}/bin/fabric-ca-client register --id.name peer0-org1 --id.secret peerpw --id.type peer
# ${PWD}/bin/fabric-ca-client register --id.name admin-org0 --id.secret adminpw --id.type admin --id.attrs "hf.Registrar.Roles=client,hf.Registrar.Attributes=*,hf.Revoker=true,hf.GenCRL=true,admin=true:ecert,abac.init=true:ecert"

# 启动peer
export FABRIC_CA_CLIENT_HOME=${PWD}/org1/ca/peer0
${PWD}/bin/fabric-ca-client enroll -u http://peer0-org1:peerpw@localhost:7054
mkdir ${PWD}/org1/ca/peer0/msp/admincerts
cp ${PWD}/org0/ca/admin/msp/signcerts/cert.pem ${PWD}/org1/ca/peer0/msp/admincerts/org1-admin-cert.pem

docker-compose -f docker-compose.yml up -d peer0.org1.example.com
docker ps -a

# 启动orderer
export FABRIC_CA_CLIENT_HOME=${PWD}/org0/ca/orderer
${PWD}/bin/fabric-ca-client enroll -u http://orderer-org0:ordererpw@localhost:7054
mkdir ${PWD}/org0/ca/orderer/msp/admincerts
cp ${PWD}/org0/ca/admin/msp/signcerts/cert.pem ${PWD}/org0/ca/orderer/msp/admincerts/orderer-admin-cert.pem

mkdir config
${PWD}/bin/configtxgen -profile OneOrgOrdererGenesis -outputBlock ./config/genesis.block
${PWD}/bin/configtxgen -profile OneOrgChannel -outputCreateChannelTx ./config/channel.tx -channelID mychannel

docker-compose -f docker-compose.yml up -d orderer.example.com
docker ps -a
