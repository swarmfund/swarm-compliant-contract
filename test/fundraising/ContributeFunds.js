const {BN, constants, expectEvent, shouldFail} = require('openzeppelin-test-helpers');
const crypto = require('crypto');
const moment = require('moment');
const helpers = require('../token/helpers');
const {encodeTransfer} = require('../token/utils');

const SwarmPoweredFundraiseMock = artifacts.require('SwarmPoweredFundraiseMock');
const SwarmPoweredFundraiseTerminatedMock = artifacts.require('SwarmPoweredFundraiseTerminatedMock');
const SwarmTokenMock = artifacts.require('SwarmTokenMock');

contract('SwarmPoweredFundraise', async function ([_, whitelistManager /*authority*/, owner, issuer, contributor]) {
  const ercTotalSupply = new BN(10000);
  const amount = new BN(10);

  beforeEach(async function () {
    this.swarmPoweredFundraiseMock = await SwarmPoweredFundraiseMock.new({from: owner});
    this.swarmTokenMock = await SwarmTokenMock.new(owner, ercTotalSupply, {from: owner})
  });
 
  describe('Handling incoming contributions', function () {

    it('should allow anyone to contribute ETH to the contract', async function () {
      // check the current state of the contract
      const beforeBalance = await this.swarmPoweredFundraiseMock.getBalanceETH(contributor);

      // contribute funds
      await this.swarmPoweredFundraiseMock.send(amount, {from:owner});

      // check that the funds are added to the contributions of the msg.sender
      const afterBalance = await this.swarmPoweredFundraiseMock.getBalanceETH(contributor);

      assert.equal(afterBalance === beforeBalance.add(amount), true);
    });

    it('should allow anyone to contribute ERC20 token to the contract', async function () {
      // check the current state of the contract
      const beforeBalance = await this.swarmPoweredFundraiseMock.getBalanceToken(this.swarmTokenMock.address, contributor);

      // contribute
      await this.swarmTokenMock.approve(this.swarmPoweredFundraiseMock.address, amount);
      await this.swarmPoweredFundraiseMock.contribute(this.swarmTokenMock.address, amount, {from: owner});

      // check that the funds are added to the contributions of the msg.sender
      const afterBalance = await this.swarmPoweredFundraiseMock.getBalanceToken(this.swarmTokenMock.address, contributor);

      assert.equal(afterBalance === beforeBalance.add(amount), true);
    });

    it('should reject ETH contributions after the fundraise has terminated', async function () {
      // check current state of contract
      const beforeBalance = await this.swarmPoweredFundraiseMock.getBalanceETH(contributor);

      // send funds to terminated fundraising contract
      await this.swarmPoweredFundraiseMock.send(amount, {from:owner});

      // check that funds are NOT added to the contributions
      const afterBalance = await this.swarmPoweredFundraiseMock.getBalanceETH(contributor);

      assert.equal(afterBalance === beforeBalance, true);
    });

  });

});
