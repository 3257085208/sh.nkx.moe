<?php
/**
 * NexBook Pro · 数据导入工具
 * 用于将旧 JSON 数据迁移至新数据库
 */

header('Content-Type: text/html; charset=utf-8');
echo "<style>body{font-family:sans-serif;line-height:1.6;padding:20px;background:#f1f5f9;color:#334155} .log{background:#fff;padding:15px;border-radius:8px;border:1px solid #cbd5e1;margin-bottom:10px;font-size:13px;font-family:monospace;} .success{color:green;} .info{color:blue;} .error{color:red;font-weight:bold;}</style>";
echo "<h1>开始数据导入流程...</h1>";

// --- 1. 连接数据库 (使用与主系统相同的配置) ---
$envPath = __DIR__ . '/.env';
if (file_exists($envPath)) {
    $lines = file($envPath, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
    foreach ($lines as $line) {
        if (strpos(trim($line), '#') === 0) continue;
        list($n, $v) = explode('=', $line, 2);
        $_ENV[trim($n)] = trim($v);
    }
}

$dbHost = $_ENV['DB_HOST'] ?? '127.0.0.1';
$dbName = $_ENV['DB_NAME'] ?? 'cabinet_manager';
$dbUser = $_ENV['DB_USER'] ?? 'root';
$dbPass = $_ENV['DB_PASS'] ?? '';

try {
    $pdo = new PDO("mysql:host=$dbHost;dbname=$dbName;charset=utf8mb4", $dbUser, $dbPass, [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC
    ]);
    echo "<div class='log success'>[系统] 数据库连接成功</div>";
} catch (PDOException $e) {
    die("<div class='log error'>[错误] 数据库连接失败: " . $e->getMessage() . "</div>");
}

// --- 2. 原始 JSON 数据 ---
$json_data = '[
  {
    "id": 4,
    "name": "浪潮5112M5",
    "type": "1U",
    "nodes": 1,
    "tenant": "大负豪",
    "mainip": "110.42.96.8",
    "start_date": "2024-07-15",
    "end_date": "2025-11-15",
    "remark": "A13铂金8252C\nKSV2407161006",
    "created_at": "2025-12-29 12:11:38",
    "updated_at": "2025-12-29 12:20:54",
    "ips": [
      { "addr": "110.42.10.240", "type": "三线BGP 10G", "price": 100 },
      { "addr": "110.42.96.69", "type": "电信100G 普防", "price": 30 },
      { "addr": "114.66.56.242", "type": "电信100G 普防", "price": 30 },
      { "addr": "114.66.56.244", "type": "电信100G 普防", "price": 30 },
      { "addr": "114.66.56.249", "type": "电信100G 普防", "price": 30 },
      { "addr": "114.66.28.187", "type": "电信100G 普防", "price": 30 },
      { "addr": "114.66.28.188", "type": "电信100G 普防", "price": 30 },
      { "addr": "114.66.28.189", "type": "电信100G 普防", "price": 30 },
      { "addr": "114.66.28.190", "type": "电信100G 普防", "price": 30 },
      { "addr": "114.66.28.191", "type": "电信100G 普防", "price": 30 }
    ],
    "start": "2024-07-15",
    "end": "2025-11-15"
  },
  {
    "id": 5,
    "name": "浪潮5212M5",
    "type": "2U",
    "nodes": 1,
    "tenant": "大负豪",
    "mainip": "110.42.96.105",
    "start_date": "2024-11-12",
    "end_date": "2025-12-12",
    "remark": "htyuty\nKSV2511122002",
    "created_at": "2025-12-29 12:13:06",
    "updated_at": "2025-12-29 12:21:17",
    "ips": [
      { "addr": "110.42.96.72", "type": "电信100G 普防", "price": 30 }
    ],
    "start": "2024-11-12",
    "end": "2025-12-12"
  },
  {
    "id": 6,
    "name": "Dell R620",
    "type": "1U",
    "nodes": 1,
    "tenant": "大负豪",
    "mainip": "110.42.65.164",
    "start_date": "2024-07-15",
    "end_date": "2025-11-15",
    "remark": "俏皮\nKSV2407161004",
    "created_at": "2025-12-29 12:16:20",
    "updated_at": "2025-12-29 12:21:51",
    "ips": [
      { "addr": "110.42.11.251", "type": "三线BGP 10G", "price": 100 }
    ],
    "start": "2024-07-15",
    "end": "2025-11-15"
  },
  {
    "id": 7,
    "name": "浪潮5112M5",
    "type": "1U",
    "nodes": 1,
    "tenant": "大负豪",
    "mainip": "110.42.96.16",
    "start_date": "2025-10-28",
    "end_date": "2025-11-28",
    "remark": "Ana\nKSV2507111003",
    "created_at": "2025-12-29 12:18:34",
    "updated_at": "2025-12-29 12:19:34",
    "ips": [
      { "addr": "110.42.14.213", "type": "三线BGP 10G", "price": 100 },
      { "addr": "110.42.96.125", "type": "电信100G 普防", "price": 30 }
    ],
    "start": "2025-10-28",
    "end": "2025-11-28"
  }
]';

$items = json_decode($json_data, true);

if (!$items) {
    die("<div class='log error'>JSON 解析失败，请检查格式</div>");
}

// --- 3. 循环处理数据 ---
foreach ($items as $item) {
    echo "<div class='log'>";
    $pdo->beginTransaction(); // 开启事务，保证数据完整性

    try {
        // A. 处理用户 (tenant)
        $username = trim($item['tenant']);
        if (empty($username)) $username = '默认用户';

        // 检查用户是否存在
        $stmt = $pdo->prepare("SELECT id FROM users WHERE username = ?");
        $stmt->execute([$username]);
        $userId = $stmt->fetchColumn();

        if ($userId) {
            echo "<span class='info'>[用户] 用户 '{$username}' 已存在 (ID: {$userId})。</span><br>";
        } else {
            // 不存在则创建，默认密码 123456
            $defaultPass = password_hash('123456', PASSWORD_DEFAULT);
            $stmt = $pdo->prepare("INSERT INTO users (username, password, role) VALUES (?, ?, 'user')");
            $stmt->execute([$username, $defaultPass]);
            $userId = $pdo->lastInsertId();
            echo "<span class='success'>[用户] 新建用户 '{$username}' (ID: {$userId})，默认密码 123456。</span><br>";
        }

        // B. 处理服务器
        // 注意：我们让数据库自动生成新 ID，而不是使用旧 ID，避免冲突
        $sql = "INSERT INTO servers (user_id, name, type, nodes, mainip, start_date, end_date, remark, status) 
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'active')";
        
        $stmt = $pdo->prepare($sql);
        $stmt->execute([
            $userId,
            $item['name'],
            $item['type'],
            $item['nodes'],
            $item['mainip'],
            $item['start_date'],
            $item['end_date'],
            $item['remark']
        ]);
        $newServerId = $pdo->lastInsertId();
        echo "<span class='success'>[资产] 导入服务器 '{$item['name']}' 成功 (新ID: {$newServerId})。</span><br>";

        // C. 处理 IP
        if (!empty($item['ips']) && is_array($item['ips'])) {
            $ipStmt = $pdo->prepare("INSERT INTO server_ips (server_id, addr, type, price) VALUES (?, ?, ?, ?)");
            foreach ($item['ips'] as $ip) {
                // 有些旧数据价格可能是 null，转为 0
                $price = isset($ip['price']) ? $ip['price'] : 0;
                $ipStmt->execute([
                    $newServerId,
                    $ip['addr'],
                    $ip['type'],
                    $price
                ]);
            }
            echo "<span class='info'>[IP] 成功关联 " . count($item['ips']) . " 个额外IP。</span>";
        }

        $pdo->commit();
        echo "</div>";

    } catch (Exception $e) {
        $pdo->rollBack();
        echo "<span class='error'>[失败] 导入 {$item['name']} 时出错: " . $e->getMessage() . "</span></div>";
    }
}

echo "<h2>🎉 全部操作结束。请前往主页查看，并删除此文件。</h2>";
echo "<a href='/' style='display:inline-block;padding:10px 20px;background:#000;color:#fff;text-decoration:none;border-radius:5px;'>返回主页</a>";
?>
