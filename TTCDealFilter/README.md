# TTC Deal Filter

Master Merchant's guild store **deal rating** for AwesomeGuildStore, with prices from **Tamriel Trade Centre** instead of Master Merchant's sales history. For people who use TTC and don't want to run Master Merchant just for its deal filter.

- Every guild store listing shows how far below the TTC average price it is (e.g. `42.50%`), colored from *Overpriced* (red) through the item quality colors up to *Buy it!* (gold).
- An AwesomeGuildStore **Deal Range** filter (Overpriced … Buy it!) and a **Profit Range** filter.
- A **Deal Percent** sort order.

The rating uses Master Merchant's thresholds: how big the margin is, how much gold you'd make, and how many sales TTC has seen for the item. Listings TTC has no price for get no rating.

<!-- screenshot: guild store results with deal percentages and the Deal Range filter -->

## Credits and license

The deal calculation, the AwesomeGuildStore filter and sort order code, and the filter icons are adapted from **[Master Merchant](https://www.esoui.com/downloads/info2753-MasterMerchant3.0.html)** (Dan Stone, Chris Lasswell / Philgo68, Sharlikran and contributors). That code is under Master Merchant's BSD license, included in `LICENSE`. This addon isn't affiliated with or endorsed by Master Merchant's authors.

## Upgrading from MasterMeme

This is the same addon under a new name. Disable or delete the old `MasterMeme` folder: both register the same AwesomeGuildStore filters.

## Requirements

- AwesomeGuildStore
- Tamriel Trade Centre
- LibMediaProvider-1.0
