# Decentralized Oracle for Reliable Event Outcome Verification

This project implements a decentralized oracle system for trustless verification of real-world event outcomes, with a specific application in sports match outcomes. The smart contracts are written in Solidity and are deployable on Ethereum Virtual Machine (EVM)-compatible platforms.

## Introduction

In blockchain systems, Oracles provide a means to securely verify and transmit off-chain event data without reliance on a single trusted entity. Traditional approaches often depend on centralized data sources as Oracle, which can lead to conflicts of interest and potentially manipulated data. This project aims to address these challenges by creating an oracle that aggregates votes from independent participants who verify event outcomes. The example of sports outcomes is used to demonstrate how this model can overcome data reliability concerns through a decentralized approach. Key features include Proof-of-Work (PoW) voting and stake-based rewards for accuracy.

## Workflow Overview

The Oracle and Outcome Settlement contracts work together to provide a fully decentralized platform for outcome verification.

### Outcome Settlement Contract

This contract allows participants to submit bets on event outcomes, such as sports matches. Participants can place bets by sending tokens to the contract. The contract controls which events are open for participation and leverages the Oracle for final outcome verification. Once the Oracle validates an event's outcome, the contract allocates winnings to correct participants and a small portion to voters in the Oracle who contributed to the correct outcome verification.

### Decentralized Oracle Contract

The Oracle operates autonomously, with the following workflow:

1. **Event Registration**: The contract owner registers events that can be tracked.
2. **Voting Period**: Once an event concludes, the Oracle opens a voting period. Anyone can submit votes indicating the outcome, by paying a small voting fee alongside a Proof-of-Work calculation (providing a nonce and a challenge string). PoW serves to prevent malicious entities from manipulating results by limiting the number of votes any one participant can cast within the voting timeframe.
3. **Vote Verification**: Submitted votes must satisfy the PoW difficulty and are only accepted if the nonce and address hash match the required challenge.
4. **Outcome Finalization**: At the end of the voting period, the Oracle aggregates votes and determines the consensus outcome, which is then relayed to the Outcome Settlement contract.

Participants who voted accurately receive a portion of the betting pool as a reward along with the initial voting fee, while incorrect votes are penalized by their voting fee not being returned, incentivizing participants to vote truthfully.

### Proof-of-Work Mechanism

To maintain integrity, PoW ensures that voters cannot spam the Oracle. Each vote requires computational effort, reducing the likelihood of manipulation. The challenge string and difficulty parameters are adjusted per event to balance security and accessibility. This system also prevents reuse of nonces by incorporating the voter's address in the PoW calculation.

## System Incentives and Bootstrapping

To build trust and encourage participation, the oracle rewards voters who correctly verify real-world outcomes by providing them a small portion of the betting pool for that mathch outcome. This self-reinforcing incentive system is crucial for bootstrapping user adoption. As the betting pool grows, reward size increases, attracting more voters and creating a positive feedback loop that enhances system reliability over time which inturn increases the trust in the system which incentivises betting pool to grow. Simila other PoW systems, this feedback loop is central to establishing a decentralized network. This bootstrapping concept is not unheard of in proof-of-worf blockchains, many proof-of-work blockchains like Bitcoin and Ethereum relied on a similar bootstrapping to establish themselves.

## Deployment Instructions

Deploy the Oracle contract on any Ethereum-compatible network. The Outcome Settlement contract is automatically generated and deployed by the Oracle upon initialization.

## Deployed Contracts on Goerli TestNet

The contracts are deployed on Goerli TestNet:
- Oracle Contract: `0x6Ef8759D027Bf45C7F02E786eC4EFFad4fb4429c`
- Outcome Settlement Contract: `0xc176Ca8F7303179c81a1B1fc38da6A4AAd0b283F`
