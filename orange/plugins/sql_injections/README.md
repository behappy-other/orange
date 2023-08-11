### init sql

```sql
SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- ----------------------------
-- Table structure for sql_injections
-- ----------------------------
DROP TABLE IF EXISTS `sql_injections`;
CREATE TABLE `sql_injections`  (
  `id` int(11) UNSIGNED NOT NULL AUTO_INCREMENT,
  `key` varchar(255) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '',
  `value` varchar(2000) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '',
  `type` varchar(11) CHARACTER SET utf8 COLLATE utf8_general_ci NULL DEFAULT '0',
  `op_time` timestamp(0) NOT NULL DEFAULT CURRENT_TIMESTAMP(0) ON UPDATE CURRENT_TIMESTAMP(0),
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `unique_key`(`key`) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 16 CHARACTER SET = utf8 COLLATE = utf8_general_ci ROW_FORMAT = Dynamic;

-- ----------------------------
-- Records of sql_injections
-- ----------------------------
INSERT INTO `sql_injections` (`id`, `key`, `value`, `type`, `op_time`)
VALUES
    (1,'1','{}','meta','2016-11-11 11:11:11');

SET FOREIGN_KEY_CHECKS = 1;
```