// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./LotteryCommon.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/ILottery.sol";
/**
 * @title Lottery
 * @dev Main contract for the Lottery gambling protocol.
 */
contract Lottery is LotteryCommon, ILottery {
    // The extension contract address is now private and immutable.
    // Fix Audit M-02: Extension address is set in the constructor and cannot be changed by the owner.
    ILotteryExtension private immutable extension;

    constructor(IERC20 _usdc, ILotteryExtension _extension)
        LotteryCommon("Lottery Ticket", "LOTTERY", msg.sender)
    {
        usdc = _usdc;
        extension = _extension;
        ticketPrice = 200_000 * 10 ** 6;
    }

    // --- Liquidity Management ---
    function depositLiquidity(uint256 amount) external onlyOwner {
        require(usdc.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        liquidity += amount;
    }

    // Owner may set any withdrawal amount; pending withdrawals are public.
    function requestWithdrawal(uint256 amount) external onlyOwner {
        // Fix Audit M-01: Withdrawal delay is enforced on the owner.
        pendingWithdrawalAmount = amount;
        withdrawalRequestTime = block.timestamp;
        withdrawalRequested = true;
    }

    function executeWithdrawal() external onlyOwner {
        // Fix Audit M-01: Enforcing a 2-day delay.
        require(withdrawalRequested, "No pending withdrawal");
        require(block.timestamp >= withdrawalRequestTime + 2 days, "Withdrawal delay not passed");
        uint256 amount = pendingWithdrawalAmount;
        pendingWithdrawalAmount = 0;
        withdrawalRequested = false;
        liquidity -= amount;
        require(usdc.transfer(msg.sender, amount), "Transfer failed");
    }

    // --- Commit-Reveal ---
    function addCommitment(bytes32 commitment) external onlyOwner {
        commitments.push(commitment);
    }
    function getAvailableTickets() external view returns (uint256) {
        return commitments.length - nextCommitIndex;
    }

    // --- Ticket Purchase ---
    function purchaseTicket(string calldata userRandom) external  returns (uint256 ticketId) {
        require(liquidity >= pendingMaxWinnings() + MAX_WINNING, "Not enough liquidity reserve");
        require(usdc.transferFrom(msg.sender, address(this), ticketPrice), "Payment failed");
        liquidity += ticketPrice;

        require(nextCommitIndex < commitments.length, "No available commitments");
        bytes32 commit = commitments[nextCommitIndex];
        nextCommitIndex++;

        ticketId = nextTicketId++;
        tickets[ticketId] = Ticket({
            id: ticketId,
            purchaseTime: block.timestamp,
            expirationTime: block.timestamp + 2 days,
            redeemed: false,
            userRandom: userRandom,
            commitment: commit,
            revealed: false,
            randomComponent: 0,
            revealDeadline: block.timestamp + 1 days
        });
        _mint(msg.sender, ticketId);
    }

    function revealRandom(uint256 ticketId, string calldata reveal) external onlyOwner {
        Ticket storage ticket = tickets[ticketId];
        require(!ticket.revealed, "Already revealed");
        require(block.timestamp <= ticket.revealDeadline, "Reveal deadline passed");
        require(keccak256(abi.encodePacked(reveal)) == ticket.commitment, "Invalid reveal");

        bytes32 combined = keccak256(abi.encodePacked(ticket.userRandom, reveal));
        uint256 randomVal = uint256(combined) % (MAX_RANDOM + 1);
        ticket.randomComponent = randomVal;
        ticket.revealed = true;
    }

    // Only unredeemed and unexpired tickets count toward liquidity reservation.
    function pendingMaxWinnings() public view returns (uint256) {
        uint256 count = 0;
        for (uint256 i = 0; i < nextTicketId; i++) {
            if (!tickets[i].redeemed && block.timestamp < tickets[i].expirationTime) {
                count++;
            }
        }
        return count * MAX_WINNING;
    }

    // --- Solve Functions in Main Contract ---
    // (Sorted in increasing order of magic number)

    function solveMulmod15053(uint256 ticketId, uint256 x) external {
        _solveMulmodInternal(ticketId, x,
            15053184396576981639254393052090194707529370822995732413175600909352185668099,
            15053);
    }

    function solveMulmod18015(uint256 ticketId, uint256 x) external {
        _solveMulmodInternal(ticketId, x,
            18015083707315377366386617667408323019692147139636184166961620636644408328883,
            18015);
    }

    function solveMulmod19248(uint256 ticketId, uint256 x) external {
        _solveMulmodInternal(ticketId, x,
            19248672707204134002532839657668288555722468284754079619119340491107327203947,
            19248);
    }

    function solveMulmod25536(uint256 ticketId, uint256 x) external {
        _solveMulmodInternal(ticketId, x,
            25536909217330731796830263634676355491176839850034307445657601320598431696689,
            25536);
    }

    function solveMulmod28111(uint256 ticketId, uint256 x) external {
        _solveMulmodInternal(ticketId, x,
            28111362664671187815107537437503715494835165531990605995671602340143059685823,
            28111);
    }

    function solveMulmod30726(uint256 ticketId, uint256 x) external {
        _solveMulmodInternal(ticketId, x,
            30726355382707936275158671604764717390329907807290863816954081244497768295469,
            30726);
    }
    function solveMulmod34651(uint256 ticketId, uint256 x) external {
        _solveMulmodInternal(ticketId, x,
            34651172457072978507050389974357124014488083862473038749658799685494001483587,
            34651);
    }

    function solveMulmod38257(uint256 ticketId, uint256 x) external {
        _solveMulmodInternal(ticketId, x,
            38257417809064525743385177813705799558086019504046675232597061625325111810171,
            38257);
    }

    function solveMulmod44864(uint256 ticketId, uint256 x) external {
        _solveMulmodInternal(ticketId, x,
            44864632277203371877548277288308797146590864564889897347688316905146021819179,
            44864);
    }

    function solveMulmod48351(uint256 ticketId, uint256 x) external {
        _solveMulmodInternal(ticketId, x,
            48351321442395152077996035591156717911360174407399189474636996744634994366557,
            48351);
    }

    function solveMulmod53568(uint256 ticketId, uint256 x) external {
        _solveMulmodInternal(ticketId, x,
            53568219114564968718401873441861931652184502697476817256618022947837164575833,
            53568);
    }

    function solveMulmod53604(uint256 ticketId, uint256 x) external {
        _solveMulmodInternal(ticketId, x,
            53604019928014247301010910030865761837892941538316469536883387171651321826793,
            53604);
    }

    function solveMulmod61073(uint256 ticketId, uint256 x) external {
        _solveMulmodInternal(ticketId, x,
            61073095403069075192064711994132694414056334683451317131380479344791378338351,
            61073);
    }

    function solveMulmod63592(uint256 ticketId, uint256 x) external {
        _solveMulmodInternal(ticketId, x,
            63592827360157875441734096610201246971746341225486158545336278752407376823929,
            63592);
    }

    function solveMulmod68324(uint256 ticketId, uint256 x) external {
        _solveMulmodInternal(ticketId, x,
            68324181304799324838028441827568133937820050312036682824696889003478753106647,
            68324);
    }

    function solveMulmod69175(uint256 ticketId, uint256 x) external {
        _solveMulmodInternal(ticketId, x,
            69175372045450660633961293953459723804233272246192202736787510099483938456431,
            69175);
    }

    function solveMulmod72570(uint256 ticketId, uint256 x) external {
        _solveMulmodInternal(ticketId, x,
            72570674747514649608192508836126313178997610685331027552963331749924040564499,
            72570);
    }

    function solveMulmod74676(uint256 ticketId, uint256 x) external {
        _solveMulmodInternal(ticketId, x,
            74676780033980485437913401077427820332718269893003639296010131219123137164597,
            74676);
    }

    function solveMulmod77566(uint256 ticketId, uint256 x) external {
        _solveMulmodInternal(ticketId, x,
            77566085771813559625883452425800839196792277040599469408400724605061102036037,
            77566);
    }

    function solveMulmod79137(uint256 ticketId, uint256 x) external {
        _solveMulmodInternal(ticketId, x,
            79137722691301624362420433186352982489351162037939303837145699508857071777661,
            79137);
    }

    function solveMulmod79579(uint256 ticketId, uint256 x) external {
        _solveMulmodInternal(ticketId, x,
            79579108496903459265479922692279806648277046090785083562348090059784405405489,
            79579);
    }

    function solveMulmod81474(uint256 ticketId, uint256 x) external {
        _solveMulmodInternal(ticketId, x,
            81474084751452449365045324284636077866469298087684194730184885755796705956347,
            81474);
    }

    function solveMulmod82984(uint256 ticketId, uint256 x) external {
        _solveMulmodInternal(ticketId, x,
            82984919735294537293675038257445392694742561535707617932572042631574192853603,
            82984);
    }

    function solveMulmod85887(uint256 ticketId, uint256 x) external {
        _solveMulmodInternal(ticketId, x,
            8588704602072243264737818299133327525219682856935796903013663385781211987541,
            85887);
    }

    // --- Fallback Delegatecall ---
    fallback() external{
        require(address(extension) != address(0), "Extension not set");
        (bool success, bytes memory returnData) = address(extension).delegatecall(msg.data);
        assembly {
            let size := mload(returnData)
            let ptr := add(returnData, 0x20)
            switch success
            case 0 { revert(ptr, size) }
            default { return(ptr, size) }
        }
    }

}
