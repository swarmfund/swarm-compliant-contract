const {BN, constants, expectEvent, shouldFail} = require('openzeppelin-test-helpers');
const crypto = require('crypto');
const moment = require('moment');
const helpers = require('../token/helpers');
const {encodeTransfer} = require('../token/utils');

const SwarmPoweredFundraiseMock = artifacts.require('SwarmPoweredFundraiseMock');
const SwarmPoweredFundraiseFinished = artifacts.require('SwarmPoweredFundraiseFinished');
const SwarmPoweredFundraiseCanceled = artifacts.require('SwarmPoweredFundraiseCanceled');
const SwarmPoweredFundraiseExpired = artifacts.require('SwarmPoweredFundraiseExpired');
const Erc20Token = artifacts.require('SwarmTokenMock');

contract('SwarmPoweredFundraise', async function ([_, whitelistManager /*authority*/, owner, issuer, contributor]) {
  const ercTotalSupply = new BN(10000);
  const amount = new BN(10);
  const minAmount = new BN(11);
  const maxAmount = new BN(100);

  beforeEach(async function () {
    this.swarmPoweredFundraiseMock = await SwarmPoweredFundraiseMock.new({from: owner}); // @TODO change owner to be token issuer...

    this.swarmPoweredFundraiseFinished = await SwarmPoweredFundraiseFinished.new({from: owner});
    this.swarmPoweredFundraiseCanceled = await SwarmPoweredFundraiseCanceled.new({from: owner});
    this.swarmPoweredFundraiseExpired = await SwarmPoweredFundraiseExpired.new({from: owner});

    this.acceptedToken = await Erc20Token.new(owner, ercTotalSupply, {from: owner});
    this.notAcceptedToken = await Erc20Token.new(owner, ercTotalSupply, {from: owner});
  });

  describe('Handling incoming contributions', function () {

    it('should allow anyone to contribute ETH to the contract', async function () {
      // check the current state of the contract
      const beforeBalance = await this.swarmPoweredFundraiseMock.getBalanceETH(contributor);

      // contribute funds
      await this.swarmPoweredFundraiseMock.send(amount, {from: owner});

      // check that the funds are added to the contributions of the msg.sender
      const afterBalance = await this.swarmPoweredFundraiseMock.getBalanceETH(contributor);

      assert.equal(afterBalance === beforeBalance.add(amount), true);
    });

    it('should allow anyone to contribute ERC20 token to the contract', async function () {
      // check the current state of the contract
      const beforeBalance = await this.swarmPoweredFundraiseMock.getBalanceToken(this.acceptedToken.address, contributor);

      // contribute
      await this.acceptedToken.approve(this.swarmPoweredFundraiseMock.address, amount, {from: owner});
      await this.swarmPoweredFundraiseMock.contribute(this.acceptedToken.address, amount, {from: owner});

      // check that the funds are added to the contributions of the msg.sender
      const afterBalance = await this.swarmPoweredFundraiseMock.getBalanceToken(this.acceptedToken.address, contributor);

      assert.equal(afterBalance === beforeBalance.add(amount), true);
    });

    it('should allow token issuer to accept ERC20 investment of the token that is not registered', async function () {
      // check the current state of the contract
      const beforeBalance = await this.swarmPoweredFundraiseMock.getBalanceToken(this.acceptedToken.address, contributor);

      // contribute
      await this.acceptedToken.transfer(contributor, amount, {from: owner});
      await this.acceptedToken.transfer(this.acceptedToken.address, amount, {from: contributor});
      await this.swarmPoweredFundraiseMock.acceptContribution(contributor, this.acceptedToken.address, amount, {from: owner});

      // check that the funds are added to the contributions of the msg.sender
      const afterBalance = await this.swarmPoweredFundraiseMock.getBalanceToken(this.acceptedToken.address, contributor);

      assert.equal(afterBalance === beforeBalance.add(amount), true);
    });

    it('should allow token issuer to reject ERC20 investment that is not registered', async function () {
      // check the current state of the contract
      const beforeBalance = await this.swarmPoweredFundraiseMock.getBalanceToken(this.acceptedToken.address, contributor);
      const beforeErc20Balance = await this.acceptedToken.balanceOf(contributor);

      // contribute
      await this.acceptedToken.transfer(contributor, amount, {from: owner});
      await this.acceptedToken.transfer(this.acceptedToken.address, amount, {from: contributor});
      await this.swarmPoweredFundraiseMock.rejectContribution(contributor, this.acceptedToken.address, amount, {from: owner});

      // check that the funds are added to the contributions of the msg.sender
      const afterBalance = await this.swarmPoweredFundraiseMock.getBalanceToken(this.acceptedToken.address, contributor);
      const afterErc20Balance = await this.acceptedToken.balanceOf(contributor);

      assert.equal(afterBalance === beforeBalance, true);
      assert.equal(beforeErc20Balance.add(amount) === afterErc20Balance, true);
    });

  });

  describe('Handling contribution rejection', function () {
    it('should fail if it does not satisfy contribution rules - min amount in ETH', async function () {
      await shouldFail.reverting.withMessage(this.swarmPoweredFundraiseMock.send(amount, {from:owner}),
          'Contribution rule failed: min amount');
    });

    it('should fail if it does not satisfy contribution rules - min amount in ERC20', async function () {
      await this.acceptedToken.approve(this.swarmPoweredFundraiseMock.address, amount, {from: owner});
      await shouldFail.reverting.withMessage(
          this.swarmPoweredFundraiseMock.contribute(this.acceptedToken.address, amount, {from: owner}),
          'Contribution rule failed: min amount'
      );
    });

    it('should fail if it does not satisfy contribution rules - max amount in ETH', async function () {
      await shouldFail.reverting.withMessage(this.swarmPoweredFundraiseMock.send(amount, {from:owner}),
          'Contribution rule failed: max amount');
    });

    it('should fail if it does not satisfy contribution rules - max amount in ERC20', async function () {
      await this.acceptedToken.approve(this.swarmPoweredFundraiseMock.address, amount, {from: owner});
      await shouldFail.reverting.withMessage(
          this.swarmPoweredFundraiseMock.contribute(this.acceptedToken.address, amount, {from: owner}),
          'Contribution rule failed: max amount'
      );
    });

    it('should fail if it does not satisfy contribution rules - max contributors', async function () {
      await this.acceptedToken.approve(this.swarmPoweredFundraiseMock.address, amount, {from: owner});
      await shouldFail.reverting.withMessage(
          this.swarmPoweredFundraiseMock.contribute(this.acceptedToken.address, amount, {from: owner}),
          'Contribution rule failed: max contributors'
      );
    });

    it('should reject ETH contributions after the fundraising has finished', async function () {
      // send funds to finished fundraising contract
      await shouldFail.reverting.withMessage(this.swarmPoweredFundraiseFinished.send(amount, {from:owner}),
          'Contribution has been rejected: fundraising is finished');
    });

    it('should reject ETH contributions after the fundraising has been canceled', async function () {
      // send funds to canceled fundraising contract
      await shouldFail.reverting.withMessage(this.swarmPoweredFundraiseCanceled.send(amount, {from:owner}),
          'Contribution has been rejected: fundraising is canceled');
    });

    it('should reject ETH contributions after the fundraising has expired', async function () {
      // send funds to expired fundraising contract
      await shouldFail.reverting.withMessage(this.swarmPoweredFundraiseExpired.send(amount, {from:owner}),
          'Contribution has been rejected: fundraising has expired');
    });

    it('should reject contribution if ERC20 token is not accepted', async function () {
      // contribute
      await this.acceptedToken.approve(this.swarmPoweredFundraiseMock.address, amount, {from: owner});
      await shouldFail.reverting.withMessage(this.swarmPoweredFundraiseMock.contribute(this.notAcceptedToken.address, amount, {from: owner}),
          'Contribution has been rejected: currency not accepted');
    });
  });

  describe('Handling withdrawals of the contributions', function () { // @TODO move to new file
    it('should allow contributor to withdraw his investments in ETH if fundraising is finished', async function () {
      const beforeBalance = await this.swarmPoweredFundraiseMock.getBalanceETH(contributor);

      await this.swarmPoweredFundraiseMock.send(amount, {from:owner});
      await this.swarmPoweredFundraiseMock.finishFundraising({from: owner});

      await this.swarmPoweredFundraiseMock.withdrawInvestmentETH({from: owner});
      const afterBalance = await this.swarmPoweredFundraiseMock.getBalanceETH(contributor);

      assert.equal(afterBalance === beforeBalance, true);
    });

    it('should allow contributor to withdraw his investments in ERC20 token if fundraising is finished', async function () {
      const beforeBalance = await this.swarmPoweredFundraiseMock.getBalanceToken(this.acceptedToken.address, contributor);

      await this.acceptedToken.approve(this.swarmPoweredFundraiseMock.address, amount, {from: owner});
      await this.swarmPoweredFundraiseMock.contribute(this.acceptedToken.address, amount, {from: owner});
      await this.swarmPoweredFundraiseMock.finishFundraising({from: owner});

      await this.swarmPoweredFundraiseMock.withdrawInvestmentToken({from: owner});
      const afterBalance = await this.swarmPoweredFundraiseMock.getBalanceToken(contributor);

      assert.equal(afterBalance === beforeBalance, true);
    });

    it('should not allow contributor to withdraw his contribution in ETH if fundraising is not finished', async function () {
      await this.swarmPoweredFundraiseMock.send(amount, {from: owner});

      await shouldFail.reverting.withMessage(this.swarmPoweredFundraiseMock.withdrawInvestmentETH({from: owner}),
          'Contribution withdrawal has been rejected: Fundraising not finished');
    });

    it('should not allow contributor to withdraw his contribution in ERC20 if fundraising is not finished', async function () {
      await this.acceptedToken.approve(this.swarmPoweredFundraiseMock.address, amount, {from: owner});
      await this.swarmPoweredFundraiseMock.contribute(this.acceptedToken.address, amount, {from: owner});

      await shouldFail.reverting.withMessage(this.swarmPoweredFundraiseMock.withdrawInvestmentToken({from: owner}),
          'Contribution withdrawal has been rejected: Fundraising not finished');
    });
  });
});
