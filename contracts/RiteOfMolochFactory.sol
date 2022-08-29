// SPDX-License-Identifier: MIT
// @author st4rgard3n, bitbeckers, MrDeadce11 Raid Guild
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./RiteOfMoloch.sol";
import "./InitializationData.sol";

contract RiteOfMolochFactory is InitializationData, AccessControl {

    bytes32 public constant ADMIN = keccak256("ADMIN");
 

    event NewRiteOfMoloch(
        address cohortAddress,
        address deployer,
        address implementation,
        address membershipCriteria,
        address stakeToken,
        uint256 stakeAmount,
        uint256 threshold,
        uint256 time);

    // access an existing implementation of cohort staking sbt contracts
    mapping(uint256 => address) public implementations;

    // the unique identifier used to select which implementation to use for a new cohort
    uint256 public iid;

    constructor() {

        // increment the implementation id
        iid = 1;

        // deploy the initial rite of moloch implementation and set it in implementations mapping
        implementations[iid] = address(new RiteOfMoloch());

        // assign admin roles to deployer
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        
    }

     /**
     * @dev Deploys a new clone proxy instance for cohort staking
     * @param initData the complete data for initializing a new cohort
     * @param implementationSelector points to a logic contract implementation
     * @dev initData struct format
            {
           membershipCriteria: string;
            stakingAsset: string;
            treasury: string;
            threshold: BigNumber;
            assetAmount: BigNumber;
            duration: BigNumber;
            name: string;
            symbol: string;
            baseUri: string;
             }
     */
    function createCohort(
        InitData calldata initData,
        uint256 implementationSelector
    ) external returns (address) {

        // enforce that a valid implementation is selected
        require(implementationSelector > 0 && implementationSelector <= iid, "!implementation");

        // deploy cohort clone proxy with a certain implementation
        address clone = Clones.clone(implementations[implementationSelector]);

        // initialize the cohort clone
        RiteOfMoloch(clone).initialize(initData, msg.sender);

        emit NewRiteOfMoloch (
                clone,
                msg.sender,
                implementations[implementationSelector],
                initData.membershipCriteria,
                initData.stakingAsset,
                initData.assetAmount,
                initData.threshold,
                initData.duration);

        return clone;

    }

    /**
    * @dev marks a deployed contract as a suitable implementation for additional cohort formats
    * @param implementation the contract address for new cohort format logic
    */

    function addImplementation(address implementation) external onlyRole(ADMIN) {
        iid++;
        implementations[iid] = implementation;
    }

}
