// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {SavingsVault} from "../src/SavingsVault.sol";

contract SavingsVaultTest is Test {
    SavingsVault public vault;
    address public user = address(0x1);
    address public owner;

    event Deposited(address indexed user, uint256 amount, uint256 interval, uint256 releaseAmount);
    event Withdrawn(address indexed user, uint256 amount, uint256 remaining);

    function setUp() public {
        owner = address(this);
        vault = new SavingsVault();

        // Fund user with 100 ETH
        vm.deal(user, 100 ether);
    }

    function test_Deposit() public {
        vm.prank(user);
        uint256 depositAmount = 10 ether;
        uint256 interval = 7 days;
        uint256 releaseAmount = 1 ether;

        vm.expectEmit(true, true, true, true);
        emit Deposited(user, depositAmount, interval, releaseAmount);

        vault.deposit{value: depositAmount}(7, releaseAmount);

        (uint256 totalDeposited,,,,,,) = vault.getVaultDetails(user);
        assertEq(totalDeposited, depositAmount);
    }

    function test_Withdraw() public {
        // Deposit
        vm.prank(user);
        vault.deposit{value: 10 ether}(7, 1 ether);

        // Fast forward 8 days (1 period completed)
        vm.warp(block.timestamp + 8 days);

        // Check available amount before withdraw
        uint256 available = vault.availableToWithdraw(user);
        assertEq(available, 1 ether, "Should have 1 ETH available");

        // Withdraw
        vm.prank(user);
        uint256 userBalanceBefore = user.balance;
        vault.withdraw();
        uint256 userBalanceAfter = user.balance;

        // Check user received correct amount
        assertEq(userBalanceAfter - userBalanceBefore, 1 ether, "User should receive 1 ETH");

        // Check remaining in vault
        (uint256 totalDeposited, uint256 withdrawn,,,,,) = vault.getVaultDetails(user);
        assertEq(withdrawn, 1 ether, "Withdrawn amount should be 1 ETH");
        assertEq(totalDeposited - withdrawn, 9 ether, "Remaining should be 9 ETH");
    }

    function test_MultipleWithdrawals() public {
        // Deposit 10 ETH, release 1 ETH every 7 days
        vm.prank(user);
        vault.deposit{value: 10 ether}(7, 1 ether);

        console.log("=== Initial State ===");
        console.log("Start time:", block.timestamp);

        // Fast forward 15 days (2 periods should be available: days 7 and 14)
        vm.warp(block.timestamp + 15 days);
        console.log("\n=== After 15 days (2 periods) ===");
        console.log("Current time:", block.timestamp);

        uint256 available = vault.availableToWithdraw(user);
        console.log("Available to withdraw:", available / 1 ether, "ETH");
        assertEq(available, 2 ether, "Should have 2 ETH available after 15 days");

        // First withdrawal - should get 2 ETH (both periods)
        vm.prank(user);
        uint256 userBalanceBefore = user.balance;
        vault.withdraw();
        uint256 userBalanceAfter = user.balance;

        console.log("Withdrawn amount:", (userBalanceAfter - userBalanceBefore) / 1 ether, "ETH");
        assertEq(userBalanceAfter - userBalanceBefore, 2 ether, "Should withdraw 2 ETH");

        // Check vault state after first withdrawal
        (uint256 totalDeposited, uint256 withdrawn,,,,,) = vault.getVaultDetails(user);
        console.log("Total withdrawn after first withdrawal:", withdrawn / 1 ether, "ETH");
        assertEq(withdrawn, 2 ether, "Should have withdrawn 2 ETH total");

        // Fast forward another 8 days (3rd period completed)
        vm.warp(block.timestamp + 8 days);
        console.log("\n=== After another 8 days (3rd period) ===");

        available = vault.availableToWithdraw(user);
        console.log("Available to withdraw:", available / 1 ether, "ETH");
        assertEq(available, 1 ether, "Should have 1 ETH available for 3rd period");

        // Second withdrawal
        userBalanceBefore = user.balance;
        vm.prank(user);
        vault.withdraw();
        userBalanceAfter = user.balance;

        console.log("Withdrawn amount:", (userBalanceAfter - userBalanceBefore) / 1 ether, "ETH");
        assertEq(userBalanceAfter - userBalanceBefore, 1 ether, "Should withdraw 1 ETH");

        // Check after second withdrawal
        (totalDeposited, withdrawn,,,,,) = vault.getVaultDetails(user);
        console.log("Total withdrawn after second withdrawal:", withdrawn / 1 ether, "ETH");
        assertEq(withdrawn, 3 ether, "Should have withdrawn 3 ETH total");

        // Fast forward to end (remaining 7 periods)
        vm.warp(block.timestamp + 49 days); // 7 more periods
        console.log("\n=== After all periods ===");

        available = vault.availableToWithdraw(user);
        console.log("Final available to withdraw:", available / 1 ether, "ETH");
        assertEq(available, 7 ether, "Should have 7 ETH remaining");

        // Withdraw remaining
        userBalanceBefore = user.balance;
        vm.prank(user);
        vault.withdraw();
        userBalanceAfter = user.balance;

        console.log("Final withdrawal amount:", (userBalanceAfter - userBalanceBefore) / 1 ether, "ETH");
        assertEq(userBalanceAfter - userBalanceBefore, 7 ether, "Should withdraw 7 ETH");

        // Check all withdrawn
        (totalDeposited, withdrawn,,,,,) = vault.getVaultDetails(user);
        console.log("Final total withdrawn:", withdrawn / 1 ether, "ETH");
        assertEq(withdrawn, 10 ether, "All should be withdrawn");
        assertEq(totalDeposited - withdrawn, 0, "Nothing remaining");
    }

    function test_CannotWithdrawMoreThanAvailable() public {
        // Deposit
        vm.prank(user);
        vault.deposit{value: 10 ether}(7, 1 ether);

        // Fast forward 5 days (no period completed yet)
        vm.warp(block.timestamp + 5 days);

        // Try to withdraw
        vm.prank(user);
        vm.expectRevert(SavingsVault.NothingToWithdraw.selector);
        vault.withdraw();
    }

    function test_AdminFunctions() public {
        // Test setMaxDeposit
        vm.prank(owner);
        vault.setMaxDeposit(200 ether);
        assertEq(vault.maxDeposit(), 200 ether);

        // Test pause
        vm.prank(owner);
        vault.pause();
        assertTrue(vault.paused());

        // Test unpause
        vm.prank(owner);
        vault.unpause();
        assertFalse(vault.paused());
    }

    function test_NonOwnerCannotPause() public {
        vm.prank(user);
        vm.expectRevert();
        vault.pause();
    }

    function test_CannotDepositWhenPaused() public {
        vm.prank(owner);
        vault.pause();

        vm.prank(user);
        vm.expectRevert();
        vault.deposit{value: 1 ether}(7, 0.1 ether);
    }

    // Fuzz test
    function testFuzz_Deposit(uint256 depositAmount, uint256 releaseAmount) public {
        // Bound inputs to reasonable values
        depositAmount = bound(depositAmount, 0.01 ether, 100 ether);
        releaseAmount = bound(releaseAmount, 0.01 ether, depositAmount);

        vm.deal(user, depositAmount);

        vm.prank(user);
        vault.deposit{value: depositAmount}(7, releaseAmount);

        (uint256 totalDeposited,,,,,,) = vault.getVaultDetails(user);
        assertEq(totalDeposited, depositAmount);
    }
}
