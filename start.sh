#!/bin/bash

docker-compose -f docker-compose.yml down
docker rm -f $(docker ps -aq -f "name=dev-peer1-org1-mycc-1.0")
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
export FABRIC_CA_CLIENT_HOME=${PWD}/org1/admin
${PWD}/bin/fabric-ca-client enroll -u http://admin-org1:org1AdminPW@localhost:7054
mkdir ${PWD}/org1/admin/msp/admincerts
cp ${PWD}/org1/admin/msp/signcerts/cert.pem ${PWD}/org1/admin/msp/admincerts/org1-admin-cert.pem

export FABRIC_CA_CLIENT_HOME=${PWD}/org1/peer1
${PWD}/bin/fabric-ca-client enroll -u http://peer1-org1:peer1PW@localhost:7054
mkdir ${PWD}/org1/peer1/msp/admincerts
cp ${PWD}/org1/admin/msp/signcerts/cert.pem ${PWD}/org1/peer1/msp/admincerts/org1-admin-cert.pem

docker-compose -f docker-compose.yml up -d peer1-org1
docker ps -a

# 启动orderer
export FABRIC_CA_CLIENT_HOME=${PWD}/org0/admin
${PWD}/bin/fabric-ca-client enroll -u http://admin-org0:org0adminpw@localhost:7053
mkdir ${PWD}/org0/admin/msp/admincerts
cp ${PWD}/org0/admin/msp/signcerts/cert.pem ${PWD}/org0/admin/msp/admincerts/orderer-admin-cert.pem

export FABRIC_CA_CLIENT_HOME=${PWD}/org0/orderer
${PWD}/bin/fabric-ca-client enroll -u http://orderer1-org0:ordererpw@localhost:7053
mkdir ${PWD}/org0/orderer/msp/admincerts
cp ${PWD}/org0/admin/msp/signcerts/cert.pem ${PWD}/org0/orderer/msp/admincerts/orderer-admin-cert.pem

# 生成配置文件
# 创建组织0的msp目录
mkdir ${PWD}/org0/msp && mkdir ${PWD}/org0/msp/admincerts ${PWD}/org0/msp/cacerts
cp ${PWD}/org0/admin/msp/signcerts/cert.pem ${PWD}/org0/msp/admincerts/admin-org0-cert.pem
cp ${PWD}/org0/ca/ca-cert.pem ${PWD}/org0/msp/cacerts/org0-ca-cert.pem
# 创建组织1的msp目录
mkdir ${PWD}/org1/msp && mkdir ${PWD}/org1/msp/admincerts ${PWD}/org1/msp/cacerts
cp ${PWD}/org1/admin/msp/signcerts/cert.pem ${PWD}/org1/msp/admincerts/admin-org1-cert.pem
cp ${PWD}/org1/ca/ca-cert.pem ${PWD}/org1/msp/cacerts/org1-ca-cert.pem

mkdir config
${PWD}/bin/configtxgen -profile OneOrgOrdererGenesis -channelID byfn-sys-channel -outputBlock ./config/genesis.block
${PWD}/bin/configtxgen -profile OneOrgChannel -outputCreateChannelTx ./config/channel.tx -channelID mychannel

docker-compose -f docker-compose.yml up -d orderer1-org0 cli-org1
docker ps -a

# 创建，加入通道
sleep 5
echo "_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/"
echo "_/_/_/_/_/_/_/_/                      _/_/_/_/_/_/_/_/_/_/_/"
echo "_/_/_/_/_/_/_/_/     创建，加入通道   _/_/_/_/_/_/_/_/_/_/_/"
echo "_/_/_/_/_/_/_/_/                      _/_/_/_/_/_/_/_/_/_/_/"
echo "_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/"
sleep 5
docker exec -e "CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/org1/admin/msp" cli-org1 bash -c "peer channel create -c mychannel -f /etc/hyperledger/configtx/channel.tx -o orderer1-org0:7050 && peer channel join -b mychannel.block"

# 安装，部署链码
sleep 5
echo "_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/"
echo "_/_/_/_/_/_/_/_/                      _/_/_/_/_/_/_/_/_/_/_/"
echo "_/_/_/_/_/_/_/_/     安装，部署链码   _/_/_/_/_/_/_/_/_/_/_/"
echo "_/_/_/_/_/_/_/_/                      _/_/_/_/_/_/_/_/_/_/_/"
echo "_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/"
sleep 5
cp ${PWD}/chaincode/abac.go ${PWD}/org1/peer1/assets/chaincode
docker exec -e "CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/org1/admin/msp" cli-org1 bash -c "peer chaincode install -n mycc -v 1.0 -p github.com/hyperledger/fabric-samples/chaincode && peer chaincode instantiate -C mychannel -n mycc -v 1.0 -c '{\"Args\":[\"init\",\"a\",\"100\",\"b\",\"200\"]}' -o orderer1-org0:7050"
docker ps -a

# 调用，查询链码
sleep 5
echo "_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/"
echo "_/_/_/_/_/_/_/_/                      _/_/_/_/_/_/_/_/_/_/_/"
echo "_/_/_/_/_/_/_/_/     调用，查询链码   _/_/_/_/_/_/_/_/_/_/_/"
echo "_/_/_/_/_/_/_/_/                      _/_/_/_/_/_/_/_/_/_/_/"
echo "_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/"
sleep 5
docker exec -e "CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/org1/admin/msp" cli-org1 bash -c "peer chaincode query -C mychannel -n mycc -c '{\"Args\":[\"query\",\"a\"]}'"
sleep 2
docker exec -e "CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/org1/admin/msp" cli-org1 bash -c "peer chaincode invoke -C mychannel -n mycc -c '{\"Args\":[\"invoke\",\"a\",\"b\",\"10\"]}'"
sleep 2
docker exec -e "CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/org1/admin/msp" cli-org1 bash -c "peer chaincode query -C mychannel -n mycc -c '{\"Args\":[\"query\",\"a\"]}'"
