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

contract('ContributorActions', async function ([_, whitelistManager /*authority*/, owner, issuer, contributor]) {
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

    describe('Fundraising whitelist functionality', () => {
        it('', {
            // should be able to whitelist as a issuer/manager
                // increase total sum per contributor check
                // increase historical balances only if contrition rule is met check
                // move contributions to acc contribution if contribution rule are met check

            // new contribution
                // increase total sum per contributor check
                // increase historical balances only if contrition rule is met check
                // move contributions to acc contribution if contribution rule are met check

            // should be able to de-whitelist account
                // decrease total sum per contributor check
                // increase hardcap for sum per contributor only if contrition rule is met check
                // remove contributions from acc contributions

            // new contribution
                // increase total sum per contributor check

            // cannot whitelist/ de-whitelist after finished/expired/canceled fundraising
        });
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
                // if not whitelisted should fail

                // if acc contribution 0 should fail
                // if acc contributing > max amount should fail
        });

        it('');
        it('');
    });
});
