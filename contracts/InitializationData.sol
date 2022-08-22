// SPDX-License-Identifier: MIT
// @author st4rgard3n, bitbeckers, MrDeadce11 / Raid Guild
pragma solidity ^0.8.4;

contract InitializationData {

    // object is used to initialize new cohorts
    // daoAddress_ the contract address read from in order to ascertain cohort completion
    // tokenAddress_ the contract address for the asset which is staked into the cohort contract
    // treasury_ the address which receives tokens when initiates are slashed
    // shareThreshold_ the minimum amount of criteria which constitutes membership
    // minStake_ the minimum amount of staking asset required to join the cohort
    // name_ the name for the cohort's soul bound tokens
    // symbol_ the ticker symbol for cohort's soul bound token
    // baseURI_ the uniform resource identifier for accessing soul bound token metadata
    struct InitData {
        address membershipCriteria;
        address stakingAsset;
        address treasury;
        uint256 threshold;
        uint256 assetAmount;
        uint256 duration;
        string name;
        string symbol;
        string baseUri;
    }

}
