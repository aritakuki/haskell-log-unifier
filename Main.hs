module Main where

import Transformer (transformLog, transformLogs, filterSuccessful)

-- ======================
-- メインプログラム
-- ======================

main :: IO ()
main = do
  putStrLn "=== Haskell Log Unifier Demo ==="
  putStrLn ""

  -- サンプルログ
  let nginxLog = "192.168.1.1 - - [31/May/2024:10:00:00] GET /api/users 200"
  let apacheLog = "[31/May/2024:10:00:00] 192.168.1.1 GET /api/users 200"

  putStrLn "--- Nginx Log ---"
  putStrLn $ "Input: " ++ nginxLog
  case transformLog nginxLog of
    Right entry -> putStrLn $ "Parsed: " ++ show entry
    Left err -> putStrLn $ "Error: " ++ err
  putStrLn ""

  putStrLn "--- Apache Log ---"
  putStrLn $ "Input: " ++ apacheLog
  case transformLog apacheLog of
    Right entry -> putStrLn $ "Parsed: " ++ show entry
    Left err -> putStrLn $ "Error: " ++ err
  putStrLn ""

  putStrLn "--- Multiple Logs ---"
  let logs = [nginxLog, apacheLog]
  let results = transformLogs logs
  let successful = filterSuccessful results
  putStrLn $ "Total logs: " ++ show (length logs)
  putStrLn $ "Successfully parsed: " ++ show (length successful)
  putStrLn ""

  putStrLn "=== Done ==="
