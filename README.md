# ipa-validator

Give it an .ipa file, it tells you if it's decrypted or not.

## Example
```
shg@shg-mbp ~ % ipa-validator ~/Downloads/ipas/ios6/iPhoto-v1.1.1.ipa
✓ iPhoto-v1.1.1.ipa (decrypted)

shg@shg-mbp ~ % ipa-validator ~/Downloads/ipas/ios4/*.ipa
✗ Flood-It! 2.ipa (encrypted)
✗ Flood-It!.ipa (encrypted)
✗ Find iPhone 1.4.ipa (encrypted)
✗ com.tapulous.taptaprevenge4.ipa (encrypted)
✓ com.tapulous.taptaprevengeIII-iOS3.0-(Clutch-2.0.4).ipa (decrypted)
✓ Remote 2.3.ipa (decrypted)
✓ com.ebay.iphone-iOS4.0-(Clutch-2.0.4).ipa (decrypted)
```
