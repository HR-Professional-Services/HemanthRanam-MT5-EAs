# Custom Indicators & Native MQL5 Indicator Architecture

## Architectural Philosophy: Zero External Dependencies

All five production Expert Advisors in this repository are engineered to use **native MetaTrader 5 internal indicator handles** (`iMA`, `iATR`, `iADX`, `iBands`, `iRSI`).

### Key Advantages:
1. **Execution Speed & Multi-Symbol Scanning**: Native MT5 indicator calls run directly inside the terminal's optimized multi-threaded C++ engine. Custom `.mq5` indicator files require separate chart buffer bindings which introduce unnecessary overhead during multi-symbol polling.
2. **Zero Deployment Friction**: When transferring this repository to your **Lenovo ThinkPad**, there is no risk of runtime error `4802` (`INDICATOR_CANNOT_CREATE`) or missing `.ex5` indicator binaries.
3. **Memory Safety**: Every indicator handle created in each EA lifecycle is strictly cleaned up using `IndicatorRelease()` immediately after copying buffers, preventing memory leaks on your trading workstation.

If future proprietary custom indicator algorithms (such as custom Volume Footprints, Order Flow Heatmaps, or Machine Learning Python bridge models) are integrated, their source code (`.mq5`) will be maintained directly within this directory.
