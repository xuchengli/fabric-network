#!/bin/bash

export FABRIC_CFG_PATH=${PWD}

function generateCerts() {
  if [ -d "crypto-config" ]; then
    rm -Rf crypto-config
  fi
  set -x
  cryptogen generate --config=./crypto-config.yaml
  res=$?
  set +x
  if [ $res -ne 0 ]; then
    echo "Failed to generate certificates..."
    exit 1
  fi
}

function generateChannelArtifacts() {
  if [ -d "channel-artifacts" ]; then
    rm -Rf channel-artifacts
  fi
  echo "##########################################################"
  echo "#########  Generating Orderer Genesis block ##############"
  echo "##########################################################"
  set -x
  configtxgen -profile SampleMultiNodeEtcdRaft -channelID systemchannel -outputBlock ./channel-artifacts/genesis.block
  res=$?
  set +x
  if [ $res -ne 0 ]; then
    echo "Failed to generate orderer genesis block..."
    exit 1
  fi
  echo
  echo "#################################################################"
  echo "### Generating channel configuration transaction 'channel.tx' ###"
  echo "#################################################################"
  set -x
  configtxgen -profile OneOrgChannel -outputCreateChannelTx ./channel-artifacts/channel.tx -channelID mychannel
  res=$?
  set +x
  if [ $res -ne 0 ]; then
    echo "Failed to generate channel configuration transaction..."
    exit 1
  fi
}

function networkUp() {
  docker-compose -f docker-compose-cli.yaml up -d 2>&1
  docker ps -a
  if [ $? -ne 0 ]; then
    echo "ERROR !!!! Unable to start network"
    exit 1
  fi

  sleep 1
  echo "Sleeping 15s to allow etcdraft cluster to complete booting"
  sleep 14

  # now run the end to end script
  docker exec cli scripts/script.sh
  if [ $? -ne 0 ]; then
    echo "ERROR !!!! Test failed"
    exit 1
  fi
}

generateCerts
generateChannelArtifacts
networkUp
