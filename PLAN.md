# CleanM — แอปทำความสะอาด/ปรับแต่ง macOS (Swift + SwiftUI)

## Context
ผู้ใช้ต้องการแอป native macOS (macOS 14+) แนว system cleaner/optimizer ที่ได้แรงบันดาลใจจาก CleanMyMac แต่เป็นแบรนด์ของตัวเองชื่อ **CleanM** มี 5 โมดูล: Smart Scan, System Junk, Large & Old Files, Uninstaller, System Monitor (ในแอป + เมนูบาร์) โค้ดต้องคอมไพล์ได้จริง ไม่มี TODO
โฟลเดอร์ปลายทาง `/Users/iambulldog/Projects/cleanM` ว่างอยู่ (ไม่ใช่ repo WebEndpoint) เครื่องมี Xcode 27.2 / Swift 6.4, ไม่มี xcodegen → ใช้ **Swift Package + สคริปต์ประกอบ .app** (ผู้ใช้เลือก)

## โครงสร้างโปรเจกต์
```
cleanM/
  Package.swift                 # executableTarget "CleanM", platforms .macOS(.v14), swift-tools 5.10, swiftLanguageMode .v5 (เลี่ยง strict concurrency error)
  Resources/Info.plist          # CFBundleIdentifier com.iambulldog.CleanM, LSMinimumSystemVersion 14.0, NSHighResolutionCapable, LSApplicationCategoryType utilities
  Resources/CleanM.entitlements # app-sandbox = false
  scripts/build-app.sh          # swift build -c release → build/CleanM.app (Contents/MacOS, Info.plist, Resources) → codesign --force --deep -s - --entitlements
  README.md                     # วิธี build/run, การให้ Full Disk Access
  Sources/CleanM/
    App/CleanMApp.swift         # @main: WindowGroup + MenuBarExtra(.window) + Settings
    Models/   ScanItem, JunkCategory, LargeFile, InstalledApp, SystemStats, ByteFormat
    Services/ DiskScannerService (actor), CleaningService, SafetyWhitelist, AppInventoryService,
              SystemMonitorService, PermissionService (FDA), MemoryPurgeService
    ViewModels/ SmartScanVM, JunkVM, LargeFilesVM, UninstallerVM, MonitorVM (@MainActor @Observable)
    Views/    RootView (NavigationSplitView + sidebar), SmartScanView, JunkView, LargeFilesView,
              UninstallerView, MonitorView, MenuBarMonitorView, PermissionBanner
    Views/Components/ ProgressRing, ScanButton, GradientBackground, GlassCard, ConfettiView, SizeBadge, QuickLookPreview
```

## รายละเอียดการทำงาน
- **DiskScannerService (actor)**: `FileManager.enumerator(at:includingPropertiesForKeys:[.totalFileAllocatedSizeKey,.fileAllocatedSizeKey,.isDirectoryKey,.contentAccessDateKey,.isSymbolicLinkKey])` ไม่ตาม symlink, ข้าม package descendants ตามกรณี, ตรวจ `Task.isCancelled`, รายงาน progress ผ่าน `AsyncStream`/callback, ใช้ `withTaskGroup` สแกนหลายหมวดพร้อมกัน
- **CleaningService**: `FileManager.trashItem` (ค่าเริ่มต้น) หรือ `removeItem` (ถาวร, มี confirmation dialog), สรุปผล bytes ที่คืน/ข้อผิดพลาดต่อไฟล์
- **SafetyWhitelist**: ห้ามแตะ path นอก home ยกเว้นแอปใน /Applications; ปฏิเสธ cache ของ `com.apple.*` ที่สำคัญ (เช่น CloudKit, Safari ฯลฯ), cache ของแอปที่กำลังรัน (`NSWorkspace.runningApplications` bundle IDs), และตัวแอปเอง; ตรวจ path แบบ standardized/resolved symlink ก่อนลบทุกครั้ง
- **System Junk**: หมวด User Caches (ลูกระดับ 1 ของ `~/Library/Caches` ยกเว้น Homebrew), Logs (`~/Library/Logs`), Xcode DerivedData + Archives (`~/Library/Developer/Xcode/Archives`), Homebrew cache — expand ได้, checkbox รายรายการ, แสดง size+path
- **Large & Old**: `~/Downloads, Documents, Desktop, Movies`; เงื่อนไข >100MB หรือ access date > 6 เดือน; filter ขนาด/ประเภท (UTType: movie, archive, diskImage, document/pdf)/อายุ; Quick Look ผ่าน `QLPreviewPanel` (NSViewRepresentable wrapper + ปุ่ม Space), Reveal ด้วย `NSWorkspace.activateFileViewerSelecting`
- **Uninstaller**: อ่าน `.app` ใน `/Applications`, `~/Applications` ด้วย `Bundle(url:)` → id, version, icon (`NSWorkspace.icon(forFile:)`), ขนาด; leftovers จับคู่ bundle ID/ชื่อใน Application Support, Preferences (`<id>.plist`), Caches, Saved Application State (`<id>.savedState`), + Containers/HTTPStorages/WebKit; ห้ามถอนแอปของระบบ (`/System`, bundle `com.apple.*`) และแอปที่กำลังรัน (ให้ปิดก่อน); ลบไป Trash; แอปใน /Applications ที่เป็นของ root จะ fallback แจ้งข้อผิดพลาดอย่างชัดเจน
- **SystemMonitorService**: CPU จาก `host_processor_info` (delta ticks ต่อคอร์), RAM จาก `host_statistics64(HOST_VM_INFO64)` + `hw.memsize` + memory pressure (`kern.memorystatus_vm_pressure_level` sysctl), Disk จาก `URLResourceValues volumeAvailableCapacityForImportantUsage/total`, Network จาก `getifaddrs` + `if_data` (ibytes/obytes delta) — timer ทุก 1–2 วิ
- **Free Up RAM**: รัน `/usr/sbin/purge` ผ่าน `NSAppleScript "do shell script ... with administrator privileges"` (ขอรหัสผ่านจากระบบ — แอปไม่เห็นรหัส) แล้วแสดงหน่วยความจำที่ได้คืน
- **Full Disk Access**: ตรวจโดยลองอ่าน `~/Library/Safari/Bookmarks.plist`/`~/Library/Application Support/com.apple.TCC/TCC.db`; ถ้าไม่ได้ แสดง banner + ปุ่มเปิด `x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles`
- **Smart Scan**: ปุ่มวงกลมไล่สี cyan→purple→magenta, ring progress แบบ spring, สแกน Junk+Trash (`~/.Trash`)+Large&Old พร้อมกัน, สรุปพื้นที่รวม, ปุ่ม Clean (Junk+Trash ไปลบ; Large files ไม่ลบอัตโนมัติ — ให้ไปตรวจในหน้าโมดูล เพื่อความปลอดภัย) → checkmark + confetti
- **UI**: `NavigationSplitView`, sidebar โปร่งแสง, `.ultraThinMaterial` cards, `.preferredColorScheme(.dark)` เริ่มต้น, SF Symbols, spring animations

## Verification
1. `cd /Users/iambulldog/Projects/cleanM && swift build` — ต้องคอมไพล์ผ่านไม่มี error
2. `./scripts/build-app.sh` → `codesign -dv --entitlements - build/CleanM.app` ตรวจ sandbox=false
3. `open build/CleanM.app` แล้วใช้ computer-use screenshot ตรวจแต่ละหน้า: Smart Scan สแกนได้และแสดงขนาด, Junk แสดงหมวด, Monitor ตัวเลขขยับ, เมนูบาร์ทำงาน
4. ทดสอบการลบแบบปลอดภัย: สร้างไฟล์ทดสอบใน `~/Library/Caches/CleanMTest` แล้วลบผ่านแอป → ไปอยู่ใน Trash; จะไม่กด Clean กับข้อมูลจริงของผู้ใช้ระหว่างทดสอบ
5. git init ในโฟลเดอร์ cleanM (ยังไม่ commit จนกว่าผู้ใช้สั่ง)
