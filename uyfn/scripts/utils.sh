#
# Copyright IBM Corp All Rights Reserved
#
# SPDX-License-Identifier: Apache-2.0
#

# This is a collection of bash functions used by different scripts

ORDERER_CA=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/orderers/orderer1.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
PEER0_ORG1_CA=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt

# verify the result of the end-to-end test
verifyResult() {
  if [ $1 -ne 0 ]; then
    echo "!!!!!!!!!!!!!!! "$2" !!!!!!!!!!!!!!!!"
    echo "========= ERROR !!! FAILED to execute End-2-End Scenario ==========="
    echo
    exit 1
  fi
}

setGlobals() {
  CORE_PEER_LOCALMSPID="Org1MSP"
  CORE_PEER_TLS_ROOTCERT_FILE=$PEER0_ORG1_CA
  CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
  CORE_PEER_ADDRESS=peer0.org1.example.com:7051
}

_joinChannel() {
  setGlobals

  set -x
  peer channel join -b $CHANNEL_NAME.block >&log.txt
  res=$?
  set +x
  cat log.txt
  verifyResult $res "peer0.org1 has failed to join channel '$CHANNEL_NAME' "
}

installChaincode() {
  setGlobals
  set -x
  peer chaincode install -n mycc -v 1.0 -p ${CC_SRC_PATH} >&log.txt
  res=$?
  set +x
  cat log.txt
  verifyResult $res "Chaincode installation on peer0.org1 has failed"
  echo "===================== Chaincode is installed on peer0.org1 ===================== "
  echo
}

instantiateChaincode() {
  setGlobals

  set -x
  peer chaincode instantiate -o orderer1.example.com:7050 --tls --cafile $ORDERER_CA -C $CHANNEL_NAME -n mycc -v 1.0 -c '{"Args":["init","a","100","b","200"]}' >&log.txt
  res=$?
  set +x

  cat log.txt
  verifyResult $res "Chaincode instantiation on peer0.org1 on channel '$CHANNEL_NAME' failed"
  echo "===================== Chaincode is instantiated on peer0.org1 on channel '$CHANNEL_NAME' ===================== "
  echo
}

chaincodeQuery() {
  setGlobals
  echo "===================== Querying on peer0.org1 on channel '$CHANNEL_NAME'... ===================== "

  sleep 3
  echo "Attempting to Query peer0.org1 ..."
  set -x
  peer chaincode query -C $CHANNEL_NAME -n mycc -c '{"Args":["query","a"]}' >&log.txt
  res=$?
  set +x

  echo
  cat log.txt
  verifyResult $res "Query result on peer0.org1 is INVALID"
  echo "===================== Query successful on peer0.org1 on channel '$CHANNEL_NAME' ===================== "
  echo
}

chaincodeInvoke() {
  setGlobals

  set -x
  peer chaincode invoke -o orderer1.example.com:7050 --tls --cafile $ORDERER_CA -C $CHANNEL_NAME -n mycc --peerAddresses $CORE_PEER_ADDRESS --tlsRootCertFiles $PEER0_ORG1_CA -c '{"Args":["invoke","a","b","10"]}' >&log.txt
  res=$?
  set +x

  cat log.txt
  verifyResult $res "Invoke execution on peer0.org1 failed "
  echo "===================== Invoke transaction successful on peer0.org1 on channel '$CHANNEL_NAME' ===================== "
  echo
}
