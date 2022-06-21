// This is an example test file. Hardhat will run every *.js file in `test/`,
// so feel free to add new ones.

// Hardhat tests are normally written with Mocha and Chai.

// We import Chai to use its asserting functions here.
const { expect } = require("chai");
const { keccak256, defaultAbiCoder } = require("ethers/lib/utils");
const { ethers } = require("hardhat");
require("dotenv").config();

// `describe` is a Mocha function that allows you to organize your tests. It's
// not actually needed, but having your tests organized makes debugging them
// easier. All Mocha functions are available in the global scope.

// `describe` receives the name of a section of your test suite, and a callback.
// The callback must define the tests of that section. This callback can't be
// an async function.
describe("Rite of Moloch Contract", function () {
  // Mocha has four functions that let you hook into the the test runner's
  // lifecycle. These are: `before`, `beforeEach`, `after`, `afterEach`.

  // They're very useful to setup the environment for tests, and to clean it
  // up after they run.

  // A common pattern is to declare some variables, and assign them in the
  // `before` and `beforeEach` callbacks.

  let RiteOfMoloch;
  let riteOfMoloch;
  let owner;
  let addr1;
  let addr2;
  let addrs;
  const s3DaoAddress = "0x7bde8f8a3d59b42d0d8fab3a46e9f42e8e3c2de8";
  const raidTokenAddress = "0x18e9262e68cc6c6004db93105cc7c001bb103e49";
  const shareThreshold = 10;
  const member = "0xdf1064632754674acb1b804f2c65849d016eaf9d";

  // `beforeEach` will run before each test, re-deploying the contract every
  // time. It receives a callback, which can be async.
  beforeEach(async function () {
    // Get the ContractFactory and Signers here.
    RiteOfMoloch = await ethers.getContractFactory("RiteOfMoloch");
    [owner, addr1, addr2, ...addrs] = await ethers.getSigners();

    // To deploy our contract, we just have to call Token.deploy() and await
    // for it to be deployed(), which happens onces its transaction has been
    // mined.
    riteOfMoloch = await RiteOfMoloch.connect(owner).deploy(
      s3DaoAddress,
      raidTokenAddress,
      shareThreshold
    );

    // We can interact with the contract by calling `riteOfMoloch.method()`
    await riteOfMoloch.deployed();
  });

  // You can nest describe calls to create subsections.
  describe("Deployment", function () {
    it("Should set the right ADMIN", async function () {
      //convert role string to 32byte keccak hash
      const ADMIN = ethers.utils.id("ADMIN");
      //check if contract deployer has been assigned that role
      expect(await riteOfMoloch.hasRole(ADMIN, owner.address)).to.equal(true);
    });

    it("Should set the correct OPERATOR", async function () {
      //convert role string to 32byte keccak hash
      const OPERATOR = ethers.utils.id("OPERATOR");
      //check if contract deployer has been assigned that role
      expect(await riteOfMoloch.hasRole(OPERATOR, owner.address)).to.equal(
        true
      );
    });
  });

  describe("Admin and Operator only functions", function () {
    it("should Not be able to change minimum stake", async function () {
      //check if non admin can call admin function
      await expect(
        riteOfMoloch.connect(addr1).setMinimumStake(11)
      ).to.be.revertedWith(
        "AccessControl: account 0x70997970c51812dc3a010c7d01b50e0d17dc79c8 is missing role 0xdf8b4c520ffe197c5343c6f5aec59570151ef9a492f2c624fd45ddde6135ec42"
      );
    });

    it("should be able to change minimum stake", async function () {
      //change min stake with admin account
      await riteOfMoloch.connect(owner).setMinimumStake(11);
      //wait for tx to be mined
      // await tx.wait();
      //retrieve new staking amount
      const stake = await riteOfMoloch.minimumStake();
      //check to see if staking amount has changed
      expect(Number(stake)).to.equal(11);
    });

    it("should be able to change the max time", async function () {
      // set max duration with owner acct
      await riteOfMoloch.setMaxDuration(1000000000);
      //wait for tx to be mined
      // await tx.wait();
      //check max time
      const maxDuration = await riteOfMoloch.maximumTime();
      //check to make sure max time has been changed
      expect(maxDuration.toString()).to.equal("1000000000");
    });

    it("should NOT be able to change the max time", async function () {
      //make sure max duration cannot be changed by non admin acct
      await expect(
        riteOfMoloch.connect(addr2).setMaxDuration(1000000000)
      ).to.be.revertedWith(
        "AccessControl: account 0x3c44cdddb6a900fa2b585dd299e03d12fa4293bc is missing role 0x523a704056dcd17bcf83bed8b68c59416dac1119be77755efe3bde0a64e46e0c"
      );
    });
  });

  describe("Initiate Rites", function () {
    it("should join the initiation", async function () {
      //call joinInitiation with what should be a member of the s3Cohort dao included in the constructor
      const join = await riteOfMoloch.joinInitiation(member);
      //wait for tx to be mined
      const receipt = await join.wait();
      //filter for event emmission
      const event = receipt.events.filter((e) => {
        return e.event == "Initiation";
      });
      //check if member is listed in emitted initiation event
      expect(event[0].args.newInitiate.toLowerCase()).to.equal(member);
    });

    //can't get join initiation to revert
    it("should NOT be able to re-join the initiation", async function () {
      //join initiation
      const tx = await riteOfMoloch.joinInitiation(member);
      await tx.wait();
      //make sure you cannot re-join the initiation with the same address.
      await expect(riteOfMoloch.joinInitiation(member)).to.be.revertedWith(
        "You were sacrificed in a Dark Ritual!"
      );
    });

    // crashes with "Error: VM Exception while processing transaction: reverted with panic code 0x32 (Array accessed at an out-of-bounds or negative index)" when getSacrifices is called.
    it("should get all the failed initiates", async function () {
      //populate the all initiates array
      for (let address of addrs) {
        const tx = await riteOfMoloch.joinInitiation(address.address);
        await tx.wait();
      }

      //set maximum time to 1
      const maxTime = await riteOfMoloch.setMaxDuration(1);
      await maxTime.wait();

      //get all sacrifices
      const sacrifices = await riteOfMoloch.getSacrifices();
      //check length of sacrifices array.
      expect(
        sacrifices.failedInitiates.length && sacrifices.indices.length
      ).to.equal(addrs.length);
    });

    it("should claim stake of all failed initiates", async function () {
      //populate the all initiates array
      for (let address of addrs) {
        const tx = await riteOfMoloch.joinInitiation(address.address);
        await tx.wait();
      }

      //set maximum time to 1
      const maxTime = await riteOfMoloch.setMaxDuration(1);
      await maxTime.wait();

      //get all sacrifices
      const sacrifices = await riteOfMoloch.getSacrifices();

      //impersonate member acount
      await hre.network.provider.request({
        method: "hardhat_impersonateAccount",
        params: [member],
      });
      const sacrificeMember = await ethers.getSigner(member);

      //call sacrifice from impersonated member account
      const sacrifice = await riteOfMoloch
        .connect(sacrificeMember)
        .sacrifice(sacrifices.failedInitiates, sacrifices.indices);
      const promise = await sacrifice.wait();

      //filter emitted events for "sacrifice" event
      const eventArray = promise.events.filter((e) => {
        return e.event == "Sacrifice";
      });

      //check that number of sacrifices is equal to the number of failed initiates.
      expect(eventArray.length).to.equal(addrs.length);
    });

    it("should NOT be able claim stake of all failed initiates from non member account", async function () {
      //populate the all initiates array
      for (let address of addrs) {
        const tx = await riteOfMoloch.joinInitiation(address.address);
        await tx.wait();
      }

      //set maximum time to 1
      const maxTime = await riteOfMoloch.setMaxDuration(1);
      await maxTime.wait();

      //get all sacrifices
      const sacrifices = await riteOfMoloch.getSacrifices();

      //check that sacrifice is reverted when called by a non member;
      await expect(
        riteOfMoloch
          .connect(addr2)
          .sacrifice(sacrifices.failedInitiates, sacrifices.indices)
      ).to.be.revertedWith("You must be a member!");
    });
  });
});
