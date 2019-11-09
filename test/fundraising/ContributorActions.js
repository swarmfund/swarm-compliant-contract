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
const Src20Token = artifacts.require('SRC20TokenMock');

contract('ContributorActions', async function ([_, whitelistManager /*authority*/, owner, issuer, contributor, src20]) {
    const ercTotalSupply = new BN(10000);
    const amount = new BN(10);
    const minAmount = new BN(11);
    const maxAmount = new BN(100);

    const label = "mvpworkshop.co";
    const tokenAmount = new BN(1000);
    const startDate = new BN(moment().unix());
    const endDate = new BN(moment().unix() + 100);
    const softCap = new BN(100);
    const hardCap = new BN(1000);
    let baseCurrency = "0x89d24a6b4ccb1b6faa2625fe562bdd9a23260359"; // DAI

    beforeEach(async function () {
        this.swarmPoweredFundraiseMock = await SwarmPoweredFundraiseMock.new(
            label,
            src20,
            tokenAmount,
            startDate,
            endDate,
            softCap,
            hardCap,
            baseCurrency,
            {from: issuer});

        this.swarmPoweredFundraiseFinished = await SwarmPoweredFundraiseFinished.new(
            label,
            src20,
            tokenAmount,
            startDate,
            endDate,
            softCap,
            hardCap,
            baseCurrency,
            {from: issuer});

        this.swarmPoweredFundraiseCanceled = await SwarmPoweredFundraiseCanceled.new(
            label,
            src20,
            tokenAmount,
            startDate,
            endDate,
            softCap,
            hardCap,
            baseCurrency,
            {from: issuer});

        this.swarmPoweredFundraiseExpired = await SwarmPoweredFundraiseExpired.new(
            label,
            src20,
            tokenAmount,
            startDate,
            endDate,
            softCap,
            hardCap,
            baseCurrency,
            {from: issuer});

        this.acceptedToken = await Erc20Token.new(owner, ercTotalSupply, {from: owner});
        this.notAcceptedToken = await Erc20Token.new(owner, ercTotalSupply, {from: owner});
    });

    describe('Claim token functionality', () => {
        it('', async function () {
            //setup
            //whitelist
            //contribute

            //finished - pass/expired - fail /canceled - fail

            // pull
                // check token balance increased
                // check if fundraising token balance is 0
                // check if amount of tokens is correct
                // ...

            // failing
                // if acc contribution 0 should fail
                // if acc contributing > max amount should fail
        });


        it('should not be able claim tokens if accepted contributions are 0', async function () {

            await SwarmPoweredFundraiseFinished.setMinMaxAmounts(minAmount, maxAmount); 

            await SwarmPoweredFundraiseFinished.send(amount, {from: owner});

            await shouldFail.reverting.withMessage(SwarmPoweredFundraiseFinished.claimTokens({from: contributor}),
            "Cannot claim tokens: you have not contributed enough");
        
        });

        it('should not be able claim tokens if contributions do not pass contribution rules', async function () {

            await SwarmPoweredFundraiseFinished.setMinMaxAmounts(minAmount, maxAmount, {from: owner}); 

            await SwarmPoweredFundraiseFinished.send(amount, {from: contributor});
            await SwarmPoweredFundraiseFinished.send(amount, {from: contributor});
            await SwarmPoweredFundraiseFinished.send(amount, {from: contributor});

            await SwarmPoweredFundraiseFinished.deWhitelist(contributor, {from: owner}); 

            await shouldFail.reverting.withMessage(SwarmPoweredFundraiseFinished.claimTokens({from: contributor}),
            "Cannot claim tokens: you are not whitelisted");

        });

        it('should be able claim tokens if fundraising has finished', async function () {

            const isOngoing = await SwarmPoweredFundraiseFinished.isOngoing();
            const isFinished = await SwarmPoweredFundraiseFinished.isFinished();

            assert.equal(isOngoing === true, true);
            assert.equal(isFinished === true, true);
            
            const balanceERC20before = await Erc20Token.balanceOf(contributor);
            assert.equal(balanceERC20before == 0, true);

            await SwarmPoweredFundraiseFinished.claimTokens({from: contributor});

            const balanceERC20after = await Erc20Token.balanceOf(contributor);
            assert.equal(balanceERC20after > 0, true);

        });

        it('should not be able claim tokens if fundraising expired', async function () {

            const isOngoing = await SwarmPoweredFundraiseExpired.isOngoing();
            const endDate = await SwarmPoweredFundraiseExpired.endDate();
            const expiryPeriod = await SwarmPoweredFundraiseExpired.expiryPeriod();
            const now = endDate + expiryPeriod + 100;

            assert.equal(isOngoing === true, true);
            assert.equal(endDate + expiryPeriod < now === true, true);

            await shouldFail.reverting.withMessage(SwarmPoweredFundraiseExpired.claimTokens({from: contributor}),
                "Cannot claim tokens: fundraising has expired");

        });

        it('should not be able claim tokens if fundraising has been canceled', async function () {

            const isOngoing = await SwarmPoweredFundraiseCanceled.isOngoing();
            const isCancelled = await SwarmPoweredFundraiseCanceled.isCancelled();

            assert.equal(isOngoing === false, true);
            assert.equal(isCancelled === true, true);

            await shouldFail.reverting.withMessage(SwarmPoweredFundraiseCanceled.claimTokens({from: contributor}),
                "Cannot claim tokens: fundraising has been cancelled");

        });

    });
});
