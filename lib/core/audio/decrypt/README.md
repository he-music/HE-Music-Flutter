# 本地音频参数执行器

本目录只执行后端准备的 `audio_params` v1，不派生平台原始密钥，不访问 HTTP、播放器、下载队列或缓存。

来源：HE-Music `desktop/internal/audiodecrypt/transform/{parameters.go,stream.go,samples.go}`，对应后端 `srv-he-music/pkg/audio/transform`。保留原上游 `1dd6ea1743dcfc6a1ba42ccc559a28ceb41ff2b5` 的 **AGPL-3.0** 声明；流变换来自 `pkg/um/mg`、`pkg/um/qmc`，MP4 来自 `github.com/guohuiyuan/music-lib/soda/crypto.go`。本移植及派生实现沿用 AGPL-3.0，分发时应遵守该许可证的源码提供要求。

本次同步的 Go 源文件 SHA-256：

| 文件 | SHA-256 |
| --- | --- |
| parameters.go | `134423c417268b7372ae6645e102c3d1709ada59e92c8bea45be62cf1955d920` |
| stream.go | `61b4e40f4682b9f7091f49f96d254d5584125790175dcf365270be524f223da5` |
| samples.go | `524ee8066141bc79fecc2525b80b99a60a5168f16e72143886cb63486424363e` |

## API

- `AudioTransformParameters.parse(String encoded)`：解析无填充 Base64URL JSON；返回不可变 key/box 与 `int kind`、`String? userAgent`。字段为 `v/kind/key/box/hash/period/bias/first/segment/user_agent`，未知字段同 Go 一样忽略。非法参数抛出不包含执行材料的 `FormatException`。
- `transformAudioBytes(Uint8List bytes, AudioTransformParameters parameters, {int offset = 0})`：kind 1 减法、kind 2 平方索引 XOR、kind 3 分段状态流，返回副本。offset 是实际密文绝对偏移；offset 与末尾不得超过 `1 << 40`。每块结果与整段执行一致。
- `decryptAudioSamples(Uint8List bytes, AudioTransformParameters parameters)`：kind 4 完整 MP4 AES-CTR，返回副本；从 `audio_decryptor.dart` 导出。支持 8/16 字节 IV、16/24/32 字节 AES key、子样本、不加密区、`frma` 原格式与 `mp4a` 回退。每个样本重置 CTR，子样本的 clear 区不消耗密钥流。
- `decryptAudioFile({required File input, required File output, required String encodedParameters})`：返回 `Future<void>`；独立 worker isolate 执行参数解析、文件 I/O 与解密。kind 1–3 每次读取 64 KiB；kind 4 完整读取，输入限制为 `maxAudioSampleFileSize = 128 MiB`。同一文件（含符号链接和硬链接别名）拒绝执行。输出父目录须存在。

临时文件建在输出同目录下的独占临时目录，完成 flush/close 后通过 rename 发布。失败不主动删除输入或现有输出，并清理临时文件；调用者须避免在执行期间并发修改输入或替换路径。成功时允许替换已有输出文件。平台行为依赖 Dart/文件系统的同卷 rename 语义。

## 协议与边界

验证对应 Go JSON v2：版本、类型、key/box 长度、uint32 hash、每类必需/禁用字段、period/bias/first/segment 范围、User-Agent 的 UTF-8 字节长度与 CR/LF/NUL。重复 JSON 成员（包括未知成员）和非法 Unicode 拒绝。外层 RawURL 严格检查尾部位、不接受 `=`，但与 Go Base64 解码器一致忽略 CR/LF；内层 JSON 字节串使用有填充的标准 Base64、不接受 CR/LF，与 Go 一样容许非零未用尾部位。

MP4 保留 Go 执行器的连续 `mdat` 样本布局，不额外解析 chunk offset、多轨选择或 fragmented MP4。样本总数限制 `1 << 20`，box 嵌套最多 32 层；全部样本边界和样本表先验证，再复制输出。两遍扫描 senc，不构造逐样本/子样本对象图。128 MiB 限制作用于完整 MP4 输入；副本 API 的峰值缓冲内存约为两份输入加最多 4 MiB 样本尺寸表和 AES 状态，因此不等于总进程 128 MiB 内存限制。

AES 使用新增直接依赖 `pointycastle: ^4.0.0` 的 AES/SIC（CTR）；已有依赖 `crypto` 仅提供摘要，原 lock 没有可复用的 AES 传递依赖。

## 同步与验证

修改时逐文件核对 Go 源与上述 hash，并重新生成对照向量。`test/core/audio/decrypt/fixtures/go_vectors.json` 是直接执行本次 Go 源生成的 24 个流向量与 12 个 MP4 向量，而非 Dart 自实现生成。生成程序是同目录 `generate_go_vectors.go`：在临时 Go module `vectors` 下放置上述三个 Go 文件到 `transform/`，将生成程序放 module 根目录，使用支持 `encoding/json/v2` 的 Go（本次为 1.27.3）运行 `go run .`，将标准输出保存为 JSON。临时 module 不应包含其他 `main` 或探针文件。

运行：

```sh
dart format --output=none --set-exit-if-changed lib/core/audio/decrypt test/core/audio/decrypt
dart analyze lib/core/audio/decrypt test/core/audio/decrypt
flutter test test/core/audio/decrypt
```

测试包括 Go 对照向量、跨 first/segment/period/64KiB/最大 offset 的分块一致性、8/16 字节 IV、子样本 clear 区与剩余区、多样本 CTR 重置、固定/可变 stsz、原格式、扩展 box size、坏边界、输入保持、文件错误和 128 MiB 拒绝。

合成测试用于验证协议和算法一致性，不替代真实音频与 Android/iOS/macOS 设备验收。播放、缓存和下载的集成说明见 [本地音频解密](../../../../docs/local-audio-decryption.md)。
