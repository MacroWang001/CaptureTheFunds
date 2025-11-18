// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./LotteryCommon.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/ILotteryExtension.sol";
/**
 * @title LotteryExtension
 * @dev Extension contract for additional Solve functions. Inherits from LotteryCommon
 * to share the same storage layout and internal ERC721 functionality.
 */
contract LotteryExtension is LotteryCommon, ILotteryExtension {
    constructor() LotteryCommon("Lottery Ticket Extension", "LOTEXT", msg.sender) {}

    // --- Extension Solve Functions ---


    function solveMulmod89443(uint256 ticketId, uint256 x) external {
        _solveMulmodInternal(ticketId, x,
            89443337707730844253576441000475164919921185353862690141222702605619118945519,
            89443);
    }

    function solveMulmod90174(uint256 ticketId, uint256 x) external {
        _solveMulmodInternal(ticketId, x,
            90174280092026033387014114657910345862762171969973492884264940100258954766659,
            90174);
    }
    
    function solveMulmod93740(uint256 ticketId, uint256 x) external {
        _solveMulmodInternal(ticketId, x,
            93740274355322442630965224138666896865311990162144383591052371250387666421963,
            93740);
    }

    function solveMulmod98186(uint256 ticketId, uint256 x) external {
        _solveMulmodInternal(ticketId, x,
            98186150493531521540579305382049409986660883306227669446810681958127215955151,
            98186);
    }

    function solveMulmod98752(uint256 ticketId, uint256 x) external {
        _solveMulmodInternal(ticketId, x,
            98752915865316918527814397151901841675549700474424940934654604838427441915167,
            98752);
    }

    function solveMulmod99437(uint256 ticketId, uint256 x) external {
        _solveMulmodInternal(ticketId, x,
            99437592071735429176809880613391421477570142118485856504927043306116023007259,
            99437);
    }

    function solveMulmod99715(uint256 ticketId, uint256 x) external {
        _solveMulmodInternal(ticketId, x,
            99715583726313326515653467218519882146470580259304588435457398062203043154567,
            99715);
    }

    function solveMulmod99781(uint256 ticketId, uint256 x) external {
        _solveMulmodInternal(ticketId, x,
            99781487488611636961690995386748554600049565339643655133350734924179101988601,
            99781);
    }
}
