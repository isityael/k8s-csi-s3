package driver_test

import (
	"log"
	"os"

	"github.com/isityael/k8s-csi-s3/pkg/driver"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"

	"github.com/kubernetes-csi/csi-test/v5/pkg/sanity"
)

// Start with the library defaults, including gRPC transport credentials and
// timeout/volume settings, then apply this suite's endpoint and fixture paths.
func initSanityConfig(cfg *sanity.TestConfig) *sanity.TestConfig {
	defaults := sanity.NewTestConfig()
	defaults.TargetPath = cfg.TargetPath
	defaults.StagingPath = cfg.StagingPath
	defaults.Address = cfg.Address
	defaults.SecretsFile = cfg.SecretsFile
	defaults.TestVolumeParameters = cfg.TestVolumeParameters
	return &defaults
}

var _ = Describe("S3Driver", func() {

	Context("geesefs", func() {
		socket := "/tmp/csi-geesefs.sock"
		csiEndpoint := "unix://" + socket
		if err := os.Remove(socket); err != nil && !os.IsNotExist(err) {
			Expect(err).NotTo(HaveOccurred())
		}
		driver, err := driver.New("test-node", csiEndpoint)
		if err != nil {
			log.Fatal(err)
		}
		go driver.Run()

		Describe("CSI sanity", func() {
			sanityCfg := initSanityConfig(&sanity.TestConfig{
				TargetPath:  os.TempDir() + "/geesefs-target",
				StagingPath: os.TempDir() + "/geesefs-staging",
				Address:     csiEndpoint,
				SecretsFile: "../../test/secret.yaml",
				TestVolumeParameters: map[string]string{
					"mounter": "geesefs",
					"bucket":  "testbucket0",
				},
			})
			sanity.GinkgoTest(sanityCfg)
		})
	})

	Context("geesefs-no-bucket", func() {
		socket := "/tmp/csi-geesefs-no-bucket.sock"
		csiEndpoint := "unix://" + socket
		if err := os.Remove(socket); err != nil && !os.IsNotExist(err) {
			Expect(err).NotTo(HaveOccurred())
		}
		driver, err := driver.New("test-node", csiEndpoint)
		if err != nil {
			log.Fatal(err)
		}
		go driver.Run()

		Describe("CSI sanity", func() {
			sanityCfg := initSanityConfig(&sanity.TestConfig{
				TargetPath:  os.TempDir() + "/geesefs-no-bucket-target",
				StagingPath: os.TempDir() + "/geesefs-no-bucket-staging",
				Address:     csiEndpoint,
				SecretsFile: "../../test/secret.yaml",
				TestVolumeParameters: map[string]string{
					"mounter": "geesefs",
				},
			})
			sanity.GinkgoTest(sanityCfg)
		})
	})

	/*
		Context("s3fs", func() {
			socket := "/tmp/csi-s3fs.sock"
			csiEndpoint := "unix://" + socket
			if err := os.Remove(socket); err != nil && !os.IsNotExist(err) {
				Expect(err).NotTo(HaveOccurred())
			}
			driver, err := driver.New("test-node", csiEndpoint)
			if err != nil {
				log.Fatal(err)
			}
			go driver.Run()

			Describe("CSI sanity", func() {
				sanityCfg := &sanity.TestConfig{
					TargetPath:  os.TempDir() + "/s3fs-target",
					StagingPath: os.TempDir() + "/s3fs-staging",
					Address:     csiEndpoint,
					SecretsFile: "../../test/secret.yaml",
					TestVolumeParameters: map[string]string{
						"mounter": "s3fs",
						"bucket":  "testbucket1",
					},
				}
				sanity.GinkgoTest(sanityCfg)
			})
		})

		Context("rclone", func() {
			socket := "/tmp/csi-rclone.sock"
			csiEndpoint := "unix://" + socket

			if err := os.Remove(socket); err != nil && !os.IsNotExist(err) {
				Expect(err).NotTo(HaveOccurred())
			}
			driver, err := driver.New("test-node", csiEndpoint)
			if err != nil {
				log.Fatal(err)
			}
			go driver.Run()

			Describe("CSI sanity", func() {
				sanityCfg := &sanity.TestConfig{
					TargetPath:  os.TempDir() + "/rclone-target",
					StagingPath: os.TempDir() + "/rclone-staging",
					Address:     csiEndpoint,
					SecretsFile: "../../test/secret.yaml",
					TestVolumeParameters: map[string]string{
						"mounter": "rclone",
						"bucket":  "testbucket3",
					},
				}
				sanity.GinkgoTest(sanityCfg)
			})
		})
	*/
})
