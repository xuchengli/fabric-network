#!/bin/bash

docker-compose -f docker-compose.yml down
rm -rf org0 org1 config

# 启动组织0的ca
docker-compose -f docker-compose.yml up -d rca-org0
docker ps -a
sleep 5
# 注册
# Orderer (orderer1-org0)
# Orderer admin (admin-org0)
export FABRIC_CA_CLIENT_HOME=${PWD}/org0/ca/admin
${PWD}/bin/fabric-ca-client enroll -u http://rca-org0-admin:rca-org0-adminpw@localhost:7053
${PWD}/bin/fabric-ca-client register --id.name orderer1-org0 --id.secret ordererpw --id.type orderer
${PWD}/bin/fabric-ca-client register --id.name admin-org0 --id.secret org0adminpw --id.type admin --id.attrs "hf.Registrar.Roles=client,hf.Registrar.Attributes=*,hf.Revoker=true,hf.GenCRL=true,admin=true:ecert,abac.init=true:ecert"

# 启动组织1的ca
docker-compose -f docker-compose.yml up -d rca-org1
docker ps -a
sleep 5
# 注册
# Peer 1 (peer1-org1)
# Admin (admin1-org1)
export FABRIC_CA_CLIENT_HOME=${PWD}/org1/ca/admin
${PWD}/bin/fabric-ca-client enroll -u http://rca-org1-admin:rca-org1-adminpw@localhost:7054
${PWD}/bin/fabric-ca-client register --id.name peer1-org1 --id.secret peer1PW --id.type peer
${PWD}/bin/fabric-ca-client register --id.name admin-org1 --id.secret org1AdminPW --id.type admin --id.attrs "hf.Registrar.Roles=client,hf.Registrar.Attributes=*,hf.Revoker=true,hf.GenCRL=true,admin=true:ecert,abac.init=true:ecert"

# 启动peer
export FABRIC_CA_CLIENT_HOME=${PWD}/org1/peer1
${PWD}/bin/fabric-ca-client enroll -u http://peer1-org1:peer1PW@localhost:7054
export FABRIC_CA_CLIENT_HOME=${PWD}/org1/admin
${PWD}/bin/fabric-ca-client enroll -u http://admin-org1:org1AdminPW@localhost:7054
mkdir ${PWD}/org1/peer1/msp/admincerts
cp ${PWD}/org1/admin/msp/signcerts/cert.pem ${PWD}/org1/peer1/msp/admincerts/org1-admin-cert.pem

docker-compose -f docker-compose.yml up -d peer1-org1
docker ps -a

# 启动orderer
export FABRIC_CA_CLIENT_HOME=${PWD}/org0/orderer
${PWD}/bin/fabric-ca-client enroll -u http://orderer1-org0:ordererpw@localhost:7053
export FABRIC_CA_CLIENT_HOME=${PWD}/org0/admin
${PWD}/bin/fabric-ca-client enroll -u http://admin-org0:org0adminpw@localhost:7053
mkdir ${PWD}/org0/orderer/msp/admincerts
cp ${PWD}/org0/admin/msp/signcerts/cert.pem ${PWD}/org0/orderer/msp/admincerts/orderer-admin-cert.pem

# 生成配置文件
mkdir config
${PWD}/bin/configtxgen -profile OneOrgOrdererGenesis -channelID byfn-sys-channel -outputBlock ./config/genesis.block
${PWD}/bin/configtxgen -profile OneOrgChannel -outputCreateChannelTx ./config/channel.tx -channelID mychannel

docker-compose -f docker-compose.yml up -d orderer1-org0
docker ps -a

sleep 10

docker exec peer1-org1 peer channel create -c mychannel -f /etc/hyperledger/configtx/channel.tx -o orderer1-org0:7050
