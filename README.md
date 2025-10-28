# ipa-validator

Give it an .ipa file, it tells you if it's decrypted or not.

## Example
```
shg@shg-mbp Debug % ./ipa-validator /Users/shg/Downloads/ipa/ios\ 6/iPhoto-v1.1.1--iOS6.0-\(Clutch-1.4.6\)\ \(1\).ipa 
✗ iPhoto-v1.1.1--iOS6.0-(Clutch-1.4.6) (1).ipa (not encrypted)
shg@shg-mbp Debug % ./ipa-validator /Users/shg/Downloads/ipa/ios\ 4/*.ipa                                            
✓ Flood-It! 2.ipa (encrypted)
✓ Flood-It!.ipa (encrypted)
✓ Find iPhone 1.4.ipa (encrypted)
✓ com.tapulous.taptaprevenge4.ipa (encrypted)
✗ com.tapulous.taptaprevengeIII-iOS3.0-(Clutch-2.0.4).ipa (not encrypted)
✗ Remote 2.3.ipa (not encrypted)
✗ com.ebay.iphone-iOS4.0-(Clutch-2.0.4).ipa (not encrypted)
shg@shg-mbp Debug %
```
