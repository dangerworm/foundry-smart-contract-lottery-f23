# Provably Random Raffle Contracts

## About

This code is to create a provably random smart contract lottery.

## What do we want it to do?

1. Users can enter by paying for a ticket
    1. The ticket feed are going ot go to the winner during the draw
1. After X period of time, the lottery will automatically draw a  winner
    1. And this will be done programatically
1. Using Chainlink VRF and Chainlink Automation
    1. Chainlink VRF -> Randomness
    1. Chainlink Automation -> Time based trigger

## Tests!

1. Write some deploy scripts
1. Write our tests
    1. Work on a local chain
    1. Forked Testnet
    1. Forked Mainnet