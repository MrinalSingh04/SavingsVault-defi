// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

contract SavingsVault is ReentrancyGuard, Ownable, Pausable {
    // Custom Errors
    error ZeroDeposit();
    error VaultAlreadyExists();
    error ExceedsMaxDeposit(uint256 maxDeposit, uint256 attempted);
    error IntervalTooShort();
    error InvalidReleaseAmount();
    error ReleaseAmountExceedsDeposit(uint256 deposit, uint256 release);
    error NoVaultFound();
    error NothingToWithdraw();
    error TransferFailed();

    struct Vault {
        uint256 totalDeposited;
        uint256 withdrawn;
        uint256 startTime;
        uint256 interval;
        uint256 releaseAmount;
    }

    mapping(address => Vault) public vaults;
    uint256 public maxDeposit = 100 ether;

    event Deposited(address indexed user, uint256 amount, uint256 interval, uint256 releaseAmount);
    event Withdrawn(address indexed user, uint256 amount, uint256 remaining);
    event MaxDepositUpdated(uint256 oldAmount, uint256 newAmount);

    // Constructor - fixes the error!
    constructor() Ownable(msg.sender) {
        // No additional initialization needed
    }

    // Rest of your contract remains exactly the same...
    function setMaxDeposit(uint256 _amount) external onlyOwner {
        uint256 oldMax = maxDeposit;
        maxDeposit = _amount;
        emit MaxDepositUpdated(oldMax, _amount);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function deposit(uint256 intervalInDays, uint256 releaseAmount) external payable whenNotPaused {
        if (msg.value == 0) revert ZeroDeposit();
        if (vaults[msg.sender].totalDeposited > 0) revert VaultAlreadyExists();
        if (msg.value > maxDeposit) revert ExceedsMaxDeposit(maxDeposit, msg.value);
        if (intervalInDays == 0) revert IntervalTooShort();
        if (releaseAmount == 0) revert InvalidReleaseAmount();
        if (releaseAmount > msg.value) revert ReleaseAmountExceedsDeposit(msg.value, releaseAmount);

        vaults[msg.sender] = Vault({
            totalDeposited: msg.value,
            withdrawn: 0,
            startTime: block.timestamp,
            interval: intervalInDays * 1 days,
            releaseAmount: releaseAmount
        });

        emit Deposited(msg.sender, msg.value, intervalInDays * 1 days, releaseAmount);
    }

    function availableToWithdraw(address user) public view returns (uint256) {
        Vault memory v = vaults[user];
        if (v.totalDeposited == 0) return 0;

        if (v.interval == 0) return 0;

        uint256 periodsPassed = (block.timestamp - v.startTime) / v.interval;
        uint256 maxWithdrawable = periodsPassed * v.releaseAmount;

        if (maxWithdrawable > v.totalDeposited) {
            maxWithdrawable = v.totalDeposited;
        }

        if (maxWithdrawable <= v.withdrawn) return 0;

        return maxWithdrawable - v.withdrawn;
    }

    function withdraw() external nonReentrant whenNotPaused {
        if (vaults[msg.sender].totalDeposited == 0) revert NoVaultFound();

        uint256 amount = availableToWithdraw(msg.sender);
        if (amount == 0) revert NothingToWithdraw();

        vaults[msg.sender].withdrawn += amount;

        (bool sent,) = payable(msg.sender).call{value: amount}("");
        if (!sent) revert TransferFailed();

        emit Withdrawn(msg.sender, amount, vaults[msg.sender].totalDeposited - vaults[msg.sender].withdrawn);
    }

    function getVaultDetails(address user)
        external
        view
        returns (
            uint256 totalDeposited,
            uint256 withdrawn,
            uint256 startTime,
            uint256 interval,
            uint256 releaseAmount,
            uint256 available,
            uint256 remaining
        )
    {
        Vault memory v = vaults[user];
        totalDeposited = v.totalDeposited;
        withdrawn = v.withdrawn;
        startTime = v.startTime;
        interval = v.interval;
        releaseAmount = v.releaseAmount;
        available = availableToWithdraw(user);
        remaining = v.totalDeposited - v.withdrawn;
    }
}
