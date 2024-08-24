# Decentralized Oracle For Sports Betting
The above is an implementation of a Smart Contract for a decentralized Oracle to be used for Sports Betting. 
The smart contract is written in Solidity hence it can be deployed on an [Ethereum Virtual Machine](https://en.wikipedia.org/wiki/Ethereum#Virtual_machine) or any other compatible Virtual Machine.

## Introduction
Betting on sports and real-life events is one of the most widely known aspects of the gambling
industry. The current implementation of sports betting using blockchains usually follows the architecture where data is fed into the smart contract by an Oracle which in turn is a smart contract that receives data from some trusted entity like a famous sports website. The main problem with this is that
even if the betting process and the distribution of the winnings on a sports match happens
in a decentralized way through the sports betting smart contract, the Oracle itself is not decentralized. Thus the sports website or the entity that controls the Oracle can be
malicious and it may feed incorrect or false data about the outcome of a sports
match into the Oracle. This might be done if the entity itself has a possibility of huge financial gains because the controlling entity
themselves might have placed some bets in the sports betting smart contract.


This project aims at trying to solve this problem by implementing a decentralized Oracle
for the sports betting contract. The decentralized Oracle is implemented in such a way
that the outcome of a sports match is not decided by a single controlling entity, but is actually voted upon by several voters in a decentralized way. Additionally, this decentralization
is carried out by using Proof of Work.

## Workflow

The Oracle Smart contract has a unique Sports Betting Contract associated with it and it is deployed by the Oracle Contract itself when the Oracle Smart COntract is first created.

### Sports Betting Smart Contract
The Sports Betting Contract is deployed by the Oracle contract itself. Any addresses can send their ethers to the Sports Betting Contract and then
place bets on the outcomes of various sports matches available for betting. The data
of which sports matches to open for betting and the result of the outcome of the matches is
controlled by the Oracle Smart Contract. After a match is over and the results of the match are published by the Oracle, the Sports Betting Smart Contract distributes the winnings of the betting pool for that match to winners, additionally, a small percentage of winnings are also sent back to Oracle. These winnings
are then distributed by the Oracle among the voters of the match who correctly voted for
the outcome of that match, this is done to incentivize the voters of the match to vote correctly essentially establishing the validity of the Oracle (more details on this below).

### Oracle Smart Contract
When the Oracle Contract is deployed, it creates and deploys a Sports Betting Contract that is forever associated with this Oracle. Only the person who deploys the Oracle has the power to add information for new Sports matches into the Oracle, note that this is the only power this person who deployed the Oracle has. The actual voting and determination of what the outcome of the sports match was after the betting is over happens in a decentralized way. Once the match is over the Oracle announces a challenge string, its difficulty, and a voting fee for that match. The Oracle also starts a voting period immediately between which anyone can submit their votes on what the true outcome of the match was by showing Proof-Of-Work that is submit a nonce for the challenge string, along with the prediction fee by sending ethers for that match. If the challenge string, nonce, and the voter's address hashes to the required difficulty their vote for the outcome of the match is accepted. The Proof-Of-Work here ensures that a single malicious entity cannot submit a huge number of votes using different addresses as the time for voting is limited, and hence they can only do only limited computation in the stipulated time. Note that the same nonce can't be applicable for two addresses, as the nonce is dependent on the address itself. After the voting period ends the Oracle declares the outcome of the match, based on the votes received, to the Sports Betting Contract. The small percentage of winnings received by Oracle from the Sports Betting Contract is then distributed by Oracle to the voters who had voted for the match correctly along with their earlier paid prediction fee, while the malicious voters who voted incorrectly are penalized and do not receive their prediction fee back.


### Proof-of-Work and Bootstrapping
The Oracle uses Proof-of-Work to ensure that a malicious entity can't submit multiple votes using different addresses. Moreover, the Oracle incentivizes the voters to vote correctly as the real-life sports event as the voters get a small percentage of winnings from the betting pool. This workflow kind of establishes an ecosystem that would need to bootstrap itself: To incentivize voters to vote correctly as the real-life sports event the voters should be getting high rewards for predicting the correct outcome as the real-life event which will happen if the betting pool is large and hence the stakes/rewards are higher for the voters. And for the betting pool to get large, the betters have to trust the system and the Oracle so that more and more betters get attracted which will happen if many voters vote correctly and decide the same outcome as the real-life outcome. This bootstrapping concept is similar to what many proof-of-work blockchains like Bitcoin rely on.


## Deploying the Decentralized Oracle Smart Contract
To deploy, we just need to deploy the Oracle Smart Contract on an Ethereum Virtual Machine. The Sports Betting Smart Contract would be created and deployed by the Oracle Contract itself.


## Already Deployed Oracle on Goerli TestNet
The above smart contract has already been deployed on Goerli TestNet and can be found at the following addresses
- Address of Oracle Contract: 0x6Ef8759D027Bf45C7F02E786eC4EFFad4fb4429c
- Address of Sports Betting Contract: 0xc176Ca8F7303179c81a1B1fc38da6A4AAd0b283F






This Project was done as part of CS6858 course at IIT Madras by Prof. John Augustine.
