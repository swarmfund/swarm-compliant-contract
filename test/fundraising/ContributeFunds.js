const {BN, constants, expectEvent, shouldFail} = require('openzeppelin-test-helpers');
const crypto = require('crypto');
const moment = require('moment');
const helpers = require('../token/helpers');
const {encodeTransfer} = require('../token/utils');

const SwarmPoweredFundraiseMock = artifacts.require('SwarmPoweredFundraiseMock');

contract('SwarmPoweredFundraise', async function ([_, whitelistManager /*authority*/, owner, issuer, contributor]) {

  beforeEach(async function () {

    this.swarmPoweredFundraiseMock = await SwarmPoweredFundraiseMock.new({from: owner});

  });
 
  describe('Handling incoming contributions', function () {

    it('should allow anyone to contribute ETH to the contract', async function () {

      // check the current state of the contract
      let beforeBalance = new BN(0);
      beforeBalance = await this.swarmPoweredFundraiseMock.getBalanceETH(contributor);

      // contribute funds
      let amount = new BN(10);
      await this.swarmPoweredFundraiseMock.send(amount, {from:owner});

      // check that the funds are added to the contributions of the msg.sender
      let afterBalance = new BN(0);
      afterBalance = await this.swarmPoweredFundraiseMock.getBalanceETH(contributor);

      assert.equal(afterBalance === beforeBalance.add(amount), true);

    });




    it('should allow anyone to contribute DAI to the contract');

    it('should allow anyone to contribute WBTC to the contract');

    it('should allow anyone to contribute USDC to the contract');

    it('should reject ETH contributions after the fundraise has terminated');



  });

});
