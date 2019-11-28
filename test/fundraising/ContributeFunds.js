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
const Utils = artifacts.require('Utils');
const CurrencyRegistry = artifacts.require('CurrencyRegistry');
const ContributorRestrictions = artifacts.require('ContributorRestrictions');
const AffiliateManager = artifacts.require('AffiliateManager');

contract('SwarmPoweredFundraise', async function ([_, whitelistManager /*authority*/, owner, issuer, contributor]) {
  const ercTotalSupply = new BN(123456);
  const amount = new BN(198);
  const minAmountBCY = new BN(9);
  const maxAmountBCY = new BN(99);

  const label = 'TestFundraise';
  const src20 = helpers.accounts.ACCOUNT0.address;
  //const currencyRegistry = helpers.accounts.ACCOUNT1.address;
  const SRC20tokenSupply = 10000;
  const startDate = moment().unix(); // current time
  const endDate = moment().unix() + (60 * 60 * 72); // three days from current time;
  const softCapBCY = 1111;
  const hardCapBCY = 5555;

  beforeEach(async function () {

    this.currencyRegistry = await CurrencyRegistry.new({from: owner});
    this.affiliateManager = await AffiliateManager.new({from: owner});

    const utilsLib = await Utils.new();
    await SwarmPoweredFundraiseMock.link(Utils, utilsLib.address);

    this.swarmPoweredFundraiseMock = await SwarmPoweredFundraiseMock.new(
      label,
      src20,
      this.currencyRegistry.address,
      SRC20tokenSupply,
      startDate,
      endDate,
      softCapBCY,
      hardCapBCY,
      {from: owner}
    );

    this.swarmPoweredFundraiseMock.address;

    this.contributorRestrictions = await ContributorRestrictions.new(
      this.swarmPoweredFundraiseMock.address,
      {from: owner}
    );

    await this.swarmPoweredFundraiseMock.setupContract(
      minAmountBCY,
      maxAmountBCY,
      this.affiliateManager.address,
      this.contributorRestrictions.address,
      {from: owner}
    );

    // @TODO change owner to be token issuer...
    // DAI
    await this.currencyRegistry.addCurrency(
      "0x89d24A6b4CcB1B6fAA2625fE562bDD9a23260359", 
      "0x09cabEC1eAd1c0Ba254B09efb3EE13841712bE14",
      {from: owner}
    );
    this.erc20DAI = await Erc20Token.new(owner, ercTotalSupply, {from: owner});
    this.erc20DAI.address = "0x89d24A6b4CcB1B6fAA2625fE562bDD9a23260359";

    this.notAcceptedToken = await Erc20Token.new(owner, ercTotalSupply, {from: owner});

    this.acceptedToken = await Erc20Token.new(owner, ercTotalSupply, {from: owner});
    await this.currencyRegistry.addCurrency(
      this.acceptedToken.address,
      this.acceptedToken.address,
      {from: owner}
    );

    await this.currencyRegistry.setBaseCurrency(constants.ZERO_ADDRESS, {from: owner});

    await SwarmPoweredFundraiseFinished.link(Utils, utilsLib.address);
    this.swarmPoweredFundraiseFinished = await SwarmPoweredFundraiseFinished.new(
      label,
      src20,
      this.currencyRegistry.address,
      SRC20tokenSupply,
      startDate,
      endDate,
      softCapBCY,
      hardCapBCY,
      {from: owner}
    );
    //this.swarmPoweredFundraiseCanceled = await SwarmPoweredFundraiseCanceled.new({from: owner});
    //this.swarmPoweredFundraiseExpired = await SwarmPoweredFundraiseExpired.new({from: owner});

    // @TODO increase total sum per contributor checks
    // @TODO decrease total sum per contributor check
  });

  describe('Handling incoming contributions', function () {

    it('should allow anyone to contribute ETH to the contract', async function () {
      // check the current state of the contract
      let beforeBalance = await this.swarmPoweredFundraiseMock.getBalanceETH(contributor);

      // contribute funds
      await this.swarmPoweredFundraiseMock.send(amount, {from: contributor});

      // check that the funds are added to the contributions of the msg.sender
      let afterBalance = await this.swarmPoweredFundraiseMock.getBalanceETH(contributor);
      let actualBalance = await web3.eth.getBalance(this.swarmPoweredFundraiseMock.address);

      assert.equal(beforeBalance.add(amount).eq(afterBalance), true);
    });

    it('should allow anyone to contribute accepted currency (ERC20 token) to the contract', async function () {
      // check the current state of the contract
      const beforeBalance = await this.swarmPoweredFundraiseMock.getBalanceToken(contributor, this.acceptedToken.address);

      // contribute
      await this.acceptedToken.transfer(contributor, amount, {from: owner});
      await this.acceptedToken.approve(this.swarmPoweredFundraiseMock.address, amount, {from: contributor});
      await this.swarmPoweredFundraiseMock.contribute(this.acceptedToken.address, amount, "", {from: contributor});

      // check that the funds are added to the contributions of the msg.sender
      const afterBalance = await this.swarmPoweredFundraiseMock.getBalanceToken(contributor, this.acceptedToken.address);

      assert.equal(beforeBalance.add(amount).eq(afterBalance), true);
    });

    it('should not allow anyone to contribute not-acceptable currency (ERC20 token) to the contract', async function () {
      // contribute
      await shouldFail.reverting.withMessage(
        this.swarmPoweredFundraiseMock.contribute(this.notAcceptedToken.address, amount, "", {from: owner}),
        'Unsupported contribution currency'
      );
    });

  });

  describe('Handling contribution limits', function () {
    it('should fail to qualify ETH if it does not satisfy contribution rules - min amount', async function () {
      // check the current state of the contract
      let beforeBalance = await this.swarmPoweredFundraiseMock.getBalanceETH(contributor);

      let lessThanMinAmount = minAmountBCY - 1;
      // contribute funds
      await this.swarmPoweredFundraiseMock.send(lessThanMinAmount, {from: contributor});

      // check that the funds are added to the contributions of the msg.sender
      let afterBalance = await this.swarmPoweredFundraiseMock.getBalanceETH(contributor);
      let actualBalance = await web3.eth.getBalance(this.swarmPoweredFundraiseMock.address);

      assert.equal(beforeBalance.add(amount).eq(afterBalance), true);
    });

    it('should fail to qualify ERC20 if it does not satisfy contribution rules - min amount in ERC20', async function () {
      await this.acceptedToken.approve(this.swarmPoweredFundraiseMock.address, amount, {from: owner});
      await shouldFail.reverting.withMessage(
          //this.swarmPoweredFundraiseMock.contribute(this.acceptedToken.address, amount, {from: owner}),
          //example.methods['setValue(uint256,uint256)'](11, 55);
          //this.swarmPoweredFundraiseMock.contribute['address', 'uint256'](this.acceptedToken.address, amount, {from: owner}),
          this.swarmPoweredFundraiseMock.contribute['contribute(address,uint256)'](this.acceptedToken.address, amount, {from: owner}),
          
          this.swarmPoweredFundraiseMock.methods['contribute(address,uint256)'](this.acceptedToken.address, amount, {from: owner}),
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
          this.swarmPoweredFundraiseMock.contribute['contribute(address,uint256)'](this.acceptedToken.address, amount, {from: owner}),
          'Contribution rule failed: max amount'
      );
    });

    it('should fail if it does not satisfy contribution rules - max contributors', async function () {
      await this.acceptedToken.approve(this.swarmPoweredFundraiseMock.address, amount, {from: owner});
      await shouldFail.reverting.withMessage(
          this.swarmPoweredFundraiseMock.contribute['address','uint256'](this.acceptedToken.address, amount, {from: owner}),
          'Contribution rule failed: max contributors'
      );
    });

    it('should reject ETH contributions after the fundraising has finished', async function () {
      // send funds to finished fundraising contract
      await this.swarmPoweredFundraiseFinished.forceFinish();
      console.log('finishness', await this.swarmPoweredFundraiseFinished.isFinished.call());
      //      assert.equal(await this.token.owner.call() === account0, true);
      await shouldFail.reverting.withMessage(this.swarmPoweredFundraiseFinished.send(amount, {from:whitelistManager}),
          'Only owner can send ETH if fundraise has finished!');
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
      await shouldFail.reverting.withMessage(
        this.swarmPoweredFundraiseMock.contribute[''](this.notAcceptedToken.address, amount, {from: owner}),
          'Contribution has been rejected: currency not accepted');
    });
  });
/*
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
      await this.swarmPoweredFundraiseMock.contribute['contribute(address,uint256)']
      (this.acceptedToken.address, amount, {from: owner});

      await shouldFail.reverting.withMessage(this.swarmPoweredFundraiseMock.withdrawInvestmentToken({from: owner}),
          'Contribution withdrawal has been rejected: Fundraising not finished');
    });


  });
  */


});
