// benign-service: A harmless demonstration Windows service for the unquoted service path lab.
// This program implements a proper Windows service using github.com/kardianos/service.
//
// Build for Windows:
//   set GOOS=windows
//   set GOARCH=amd64
//   go build -o "Vulnerable Service.exe" .
//
// Install as a service (run from elevated prompt):
//   "Vulnerable Service.exe" install
//   "Vulnerable Service.exe" start
//
// Uninstall:
//   "Vulnerable Service.exe" stop
//   "Vulnerable Service.exe" uninstall
//
// This binary is intentionally placed in a path with spaces (e.g., C:\Program Files\Vulnerable Service\)
// to demonstrate the unquoted service path privilege escalation technique.

package main

import (
	"fmt"
	"log"
	"os"
	"path/filepath"
	"time"

	"github.com/kardianos/service"
)

var logger service.Logger

// program implements the service.Interface
type program struct {
	logFile string
}

func (p *program) Start(s service.Service) error {
	// Start should not block. Do the actual work async.
	go p.run()
	return nil
}

func (p *program) run() {
	// Open log file (create if not exists, append if exists)
	f, err := os.OpenFile(p.logFile, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
	if err != nil {
		logger.Errorf("Failed to open log file: %v", err)
		return
	}
	defer f.Close()

	fileLogger := log.New(f, "", 0)

	// Log service start
	fileLogger.Printf("=== Service Started ===")
	fileLogger.Printf("Timestamp: %s", time.Now().Format(time.RFC3339))
	fileLogger.Printf("Service Name: Vulnerable Service")
	fileLogger.Printf("Process ID: %d", os.Getpid())
	fileLogger.Printf("User: %s", os.Getenv("USERNAME"))
	fileLogger.Printf("Status: RUNNING - This is the legitimate service binary")
	fileLogger.Printf("========================")

	logger.Infof("Service started successfully. Logging to: %s", p.logFile)

	// Keep the service running and log periodic heartbeats
	ticker := time.NewTicker(30 * time.Second)
	defer ticker.Stop()

	for range ticker.C {
		fileLogger.Printf("[HEARTBEAT] Service alive at %s", time.Now().Format(time.RFC3339))
	}
}

func (p *program) Stop(s service.Service) error {
	// Stop should not block. Return with a few seconds.
	f, err := os.OpenFile(p.logFile, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
	if err == nil {
		defer f.Close()
		fileLogger := log.New(f, "", 0)
		fileLogger.Printf("=== Service Stopped ===")
		fileLogger.Printf("Timestamp: %s", time.Now().Format(time.RFC3339))
		fileLogger.Printf("========================")
	}

	logger.Infof("Service stopped.")
	return nil
}

func main() {
	// Determine log file location - same directory as the executable
	exePath, err := os.Executable()
	if err != nil {
		exePath = "unknown"
	}
	exeDir := filepath.Dir(exePath)
	logFile := filepath.Join(exeDir, "service_execution.log")

	svcConfig := &service.Config{
		Name:        "VulnSvc",
		DisplayName: "Vulnerable Service (Lab)",
		Description: "SEC-335 Lab: Service with unquoted path for privilege escalation demonstration.",
	}

	prg := &program{
		logFile: logFile,
	}

	s, err := service.New(prg, svcConfig)
	if err != nil {
		log.Fatal(err)
	}

	logger, err = s.Logger(nil)
	if err != nil {
		log.Fatal(err)
	}

	// Handle service control commands (install, uninstall, start, stop)
	if len(os.Args) > 1 {
		cmd := os.Args[1]
		switch cmd {
		case "install":
			err = s.Install()
			if err != nil {
				fmt.Printf("Failed to install service: %v\n", err)
				os.Exit(1)
			}
			fmt.Println("Service installed successfully.")
			return
		case "uninstall":
			err = s.Uninstall()
			if err != nil {
				fmt.Printf("Failed to uninstall service: %v\n", err)
				os.Exit(1)
			}
			fmt.Println("Service uninstalled successfully.")
			return
		case "start":
			err = s.Start()
			if err != nil {
				fmt.Printf("Failed to start service: %v\n", err)
				os.Exit(1)
			}
			fmt.Println("Service started successfully.")
			return
		case "stop":
			err = s.Stop()
			if err != nil {
				fmt.Printf("Failed to stop service: %v\n", err)
				os.Exit(1)
			}
			fmt.Println("Service stopped successfully.")
			return
		case "status":
			status, err := s.Status()
			if err != nil {
				fmt.Printf("Failed to get service status: %v\n", err)
				os.Exit(1)
			}
			switch status {
			case service.StatusRunning:
				fmt.Println("Service is running.")
			case service.StatusStopped:
				fmt.Println("Service is stopped.")
			default:
				fmt.Println("Service status is unknown.")
			}
			return
		default:
			fmt.Printf("Unknown command: %s\n", cmd)
			fmt.Println("Usage: Vulnerable Service.exe [install|uninstall|start|stop|status]")
			os.Exit(1)
		}
	}

	// Run as a service (called by the Windows Service Control Manager)
	err = s.Run()
	if err != nil {
		logger.Error(err)
	}
}
