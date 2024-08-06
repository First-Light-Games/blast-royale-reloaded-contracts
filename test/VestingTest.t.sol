// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {NoobToken} from "../src/NoobToken.sol";
import {Vesting} from "../src/Vesting.sol";

// contract MockERC20 is ERC20 {
//     constructor(uint256 initialSupply) NoobToken(msg.sender) {
//         NoobToken.mint(msg.sender, initialSupply);
//     }
// }

contract VestingTest is Test {
    Vesting public vesting;
    NoobToken public token;

    address public owner = address(1);
    address public beneficiary1 = address(2);
    address public beneficiary2 = address(3);
    address public beneficiary3 = address(4);

    function setUp() public {
        vm.startPrank(owner);
        token = new NoobToken(owner);
        token.mint(owner, 512000000000000000000000000);
        vesting = new Vesting(IERC20(address(token)), owner);
        token.transfer(address(vesting), 512000000000000000000000000);
        vesting.transferOwnership(owner);

        // first vesting schedule
        address[] memory beneficiaries = new address[](3);
        beneficiaries[0] = beneficiary1;
        uint256[] memory starts = new uint256[](3);
        starts[0] = block.timestamp + 1 days;
        uint256[] memory cliffDurations = new uint256[](3);
        cliffDurations[0] = 1 days;
        uint256[] memory durations = new uint256[](3);
        durations[0] = 30 days;
        uint256[] memory immediateReleaseAmounts = new uint256[](3);
        immediateReleaseAmounts[0] = 1_000 * 10 ** 18;
        uint256[] memory amountTotals = new uint256[](3);
        amountTotals[0] = 10_000 * 10 ** 18;
        bool[] memory revocables = new bool[](3);
        revocables[0] = true;

        // second vesting schedule
        beneficiaries[1] = beneficiary2;
        starts[1] = block.timestamp + 1 days;
        cliffDurations[1] = 1 days;
        durations[1] = 30 days;
        immediateReleaseAmounts[1] = 1_000 * 10 ** 18;
        amountTotals[1] = 10_000 * 10 ** 18;
        revocables[1] = true;

        // second vesting schedule
        beneficiaries[2] = beneficiary3;
        starts[2] = block.timestamp + 1 days;
        cliffDurations[2] = 1 days;
        durations[2] = 30 days;
        immediateReleaseAmounts[2] = 1_000 * 10 ** 18;
        amountTotals[2] = 10_000 * 10 ** 18;
        revocables[2] = true;

        // create the vesting schedules, can bulk create vesting schedules
        vesting.createVestingSchedules(
            beneficiaries,
            starts,
            cliffDurations,
            durations,
            immediateReleaseAmounts,
            amountTotals,
            revocables
        );

        vm.stopPrank();
    }

    function testCreateVestingSchedule() public {
        vm.startPrank(owner);

        bytes32 scheduleId = vesting.computeVestingScheduleIdForAddressAndIndex(
            beneficiary1,
            0
        );

        bytes32 scheduleId2 = vesting
            .computeVestingScheduleIdForAddressAndIndex(beneficiary2, 0);
        Vesting.VestingSchedule memory schedule = vesting.getVestingSchedule(
            scheduleId
        );

        Vesting.VestingSchedule memory schedule2 = vesting.getVestingSchedule(
            scheduleId2
        );

        assertEq(schedule.beneficiary, beneficiary1);
        assertEq(schedule.start, block.timestamp + 1 days);
        assertEq(schedule.cliffStart, block.timestamp + 2 days);
        assertEq(schedule.duration, 30 days);
        assertEq(schedule.immediateVestedAmount, 1_000 * 10 ** 18);
        assertEq(schedule.amountTotal, 10_000 * 10 ** 18);
        assertEq(schedule.revocable, true);

        assertEq(schedule2.beneficiary, beneficiary2);
        assertEq(schedule2.start, block.timestamp + 1 days);
        assertEq(schedule2.cliffStart, block.timestamp + 2 days);
        assertEq(schedule2.duration, 30 days);
        assertEq(schedule2.immediateVestedAmount, 1_000 * 10 ** 18);
        assertEq(schedule2.amountTotal, 10_000 * 10 ** 18);
        assertEq(schedule2.revocable, true);
        vm.stopPrank();
    }

    function testReleaseTokens() public {
        //  ----- test for beneficiary1 ---------------
        bytes32 scheduleId = vesting.computeVestingScheduleIdForAddressAndIndex(
            beneficiary1,
            0
        );
        // Move forward in time to after the cliff
        vm.warp(block.timestamp + 1 days);
        vm.startPrank(beneficiary1);

        uint256 releasableAmount = vesting.computeReleasableAmount(scheduleId);
        vesting.release(scheduleId, releasableAmount);

        uint256 balance = token.balanceOf(beneficiary1);
        assertEq(balance, 1_000 * 10 ** 18);

        // move to 7 days after
        vm.warp(block.timestamp + 7 days);
        uint256 releasableAmount1 = vesting.computeReleasableAmount(scheduleId);
        vesting.release(scheduleId, releasableAmount1);
        uint256 balance1 = token.balanceOf(beneficiary1);
        assertEq(balance1, 3_000 * 10 ** 18); // 1000 from the immediate release + 2000 from vesting for 6 days

        Vesting.VestingSchedule memory schedule = vesting.getVestingSchedule(
            scheduleId
        );
        assertEq(schedule.released, 3_000 * 10 ** 18);

        // move to 31 days after
        vm.warp(block.timestamp + 31 days);
        uint256 releasableAmount2 = vesting.computeReleasableAmount(scheduleId);
        vesting.release(scheduleId, releasableAmount2);
        uint256 balance2 = token.balanceOf(beneficiary1);
        assertEq(balance2, 11_000 * 10 ** 18); // total amount + initial release

        vm.stopPrank();

        //  ----- test for beneficiary2 ---------------

        bytes32 scheduleId2 = vesting
            .computeVestingScheduleIdForAddressAndIndex(beneficiary2, 0);

        // Move forward in time to after the cliff
        vm.startPrank(beneficiary2);
        vm.warp(1);
        vm.warp(block.timestamp + 1 days);
        uint256 releasableAmount_ = vesting.computeReleasableAmount(
            scheduleId2
        );
        vesting.release(scheduleId2, releasableAmount_);

        uint256 balance_ = token.balanceOf(beneficiary2);
        assertEq(balance_, 1_000 * 10 ** 18);
        vm.warp(block.timestamp + 7 days);
        uint256 releasableAmount1_ = vesting.computeReleasableAmount(
            scheduleId2
        );
        vesting.release(scheduleId2, releasableAmount1_);
        uint256 balance1_ = token.balanceOf(beneficiary2);
        assertEq(balance1_, 3_000 * 10 ** 18); // 1000 from the immediate release + 2000 from vesting for 6 days

        Vesting.VestingSchedule memory schedule2 = vesting.getVestingSchedule(
            scheduleId2
        );
        assertEq(schedule2.released, 3_000 * 10 ** 18);

        vm.warp(block.timestamp + 31 days);
        uint256 releasableAmount2_ = vesting.computeReleasableAmount(
            scheduleId2
        );
        vesting.release(scheduleId2, releasableAmount2_);
        uint256 balance2_ = token.balanceOf(beneficiary2);
        assertEq(balance2_, 11_000 * 10 ** 18);

        vm.stopPrank();
    }

    function testRevokeVestingSchedule() public {
        vm.startPrank(owner);

        bytes32 scheduleId = vesting.computeVestingScheduleIdForAddressAndIndex(
            beneficiary1,
            0
        );

        // Revoke the vesting schedule
        vesting.revoke(scheduleId);

        Vesting.VestingSchedule memory schedule = vesting.getVestingSchedule(
            scheduleId
        );
        assertEq(schedule.revoked, true);

        // Revoke the vesting schedule for beneficiary3 after 31 days
        bytes32 scheduleId1 = vesting
            .computeVestingScheduleIdForAddressAndIndex(beneficiary3, 0);

        vm.warp(block.timestamp + 31 days);
        vesting.revoke(scheduleId1);

        Vesting.VestingSchedule memory schedule1 = vesting.getVestingSchedule(
            scheduleId1
        );
        assertEq(schedule1.revoked, true);
        vm.stopPrank();
    }

    function testPauseAndWithdraw() public {
        vm.startPrank(owner);
        vesting.pause(true);
        assertEq(vesting.paused(), true);
        uint256 vestingBalance = token.balanceOf(address(vesting));
        assertEq(vestingBalance, 512000000000000000000000000);
        vesting.withdraw();
        uint256 vestingBalance1 = token.balanceOf(address(vesting));
        assertEq(vestingBalance1, 0);

        vesting.pause(false);
        assertEq(vesting.paused(), false);
        vm.stopPrank();
    }
}
