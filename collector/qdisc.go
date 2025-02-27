package tccollector

import (
	"fmt"
	"log/slog"
	"os"

	"github.com/florianl/go-tc"
	"github.com/jsimonetti/rtnetlink"
	"github.com/prometheus/client_golang/prometheus"
)

var (
	qdisclabels []string = []string{"host", "netns", "linkindex", "link", "type", "handle", "parent"}
)

// QdiscCollector is the object that will collect Qdisc data for the interface
type QdiscCollector struct {
	logger     slog.Logger
	netns      map[string][]rtnetlink.LinkMessage
	bytes      *prometheus.Desc
	packets    *prometheus.Desc
	bps        *prometheus.Desc
	pps        *prometheus.Desc
	backlog    *prometheus.Desc
	drops      *prometheus.Desc
	overlimits *prometheus.Desc
	qlen       *prometheus.Desc
}

// NewQdiscCollector create a new QdiscCollector given a network interface
func NewQdiscCollector(netns map[string][]rtnetlink.LinkMessage, qlog *slog.Logger) (prometheus.Collector, error) {
	// Setup logger for qdisc collector
	qlog = qlog.With("collector", "qdisc")
	qlog.Info("making qdisc collector")

	return &QdiscCollector{
		logger: *qlog,
		netns:  netns,
		bytes: prometheus.NewDesc(
			prometheus.BuildFQName(namespace, "qdisc", "bytes_total"),
			"Qdisc byte counter",
			qdisclabels, nil,
		),
		packets: prometheus.NewDesc(
			prometheus.BuildFQName(namespace, "qdisc", "packets_total"),
			"Qdisc packet counter",
			qdisclabels, nil,
		),
		bps: prometheus.NewDesc(
			prometheus.BuildFQName(namespace, "qdisc", "bps"),
			"Qdisc byte rate",
			qdisclabels, nil,
		),
		pps: prometheus.NewDesc(
			prometheus.BuildFQName(namespace, "qdisc", "pps"),
			"Qdisc packet rate",
			qdisclabels, nil,
		),
		backlog: prometheus.NewDesc(
			prometheus.BuildFQName(namespace, "qdisc", "backlog_total"),
			"Qdisc queue backlog",
			qdisclabels, nil,
		),
		drops: prometheus.NewDesc(
			prometheus.BuildFQName(namespace, "qdisc", "drops_total"),
			"Qdisc queue drops",
			qdisclabels, nil,
		),
		overlimits: prometheus.NewDesc(
			prometheus.BuildFQName(namespace, "qdisc", "overlimits_total"),
			"Qdisc queue overlimits",
			qdisclabels, nil,
		),
		qlen: prometheus.NewDesc(
			prometheus.BuildFQName(namespace, "qdisc", "qlen_total"),
			"Qdisc queue length",
			qdisclabels, nil,
		),
	}, nil
}

// Describe implements Collector
func (qc *QdiscCollector) Describe(ch chan<- *prometheus.Desc) {
	ds := []*prometheus.Desc{
		qc.backlog,
		qc.bps,
		qc.bytes,
		qc.packets,
		qc.drops,
		qc.overlimits,
		qc.pps,
		qc.qlen,
	}

	for _, d := range ds {
		ch <- d
	}
}

// Collect fetches and updates the data the collector is exporting
func (qc *QdiscCollector) Collect(ch chan<- prometheus.Metric) {
	// fetch the host for useage later on
	host, err := os.Hostname()
	if err != nil {
		qc.logger.Error("failed to fetch hostname", "err", err)
	}

	// iterate through the netns and devices
	for ns, devices := range qc.netns {
		for _, interf := range devices {
			// fetch all the the qdisc for this interface
			qdiscs, err := getQdiscs(uint32(interf.Index), ns)
			if err != nil {
				qc.logger.Error("failed to get qdiscs", "interface", interf.Attributes.Name, "err", err)
			}

			// iterate through all the qdiscs and sent the data to the prometheus metric channel
			for _, qd := range qdiscs {
				handleMaj, handleMin := HandleStr(qd.Handle)
				parentMaj, parentMin := HandleStr(qd.Parent)

				ch <- prometheus.MustNewConstMetric(
					qc.bytes,
					prometheus.CounterValue,
					float64(qd.Stats.Bytes),
					host,
					ns,
					fmt.Sprintf("%d", interf.Index),
					interf.Attributes.Name,
					qd.Kind,
					fmt.Sprintf("%x:%x", handleMaj, handleMin),
					fmt.Sprintf("%x:%x", parentMaj, parentMin),
				)
				ch <- prometheus.MustNewConstMetric(
					qc.packets,
					prometheus.CounterValue,
					float64(qd.Stats.Packets),
					host,
					ns,
					fmt.Sprintf("%d", interf.Index),
					interf.Attributes.Name,
					qd.Kind,
					fmt.Sprintf("%x:%x", handleMaj, handleMin),
					fmt.Sprintf("%x:%x", parentMaj, parentMin),
				)
				ch <- prometheus.MustNewConstMetric(
					qc.bps,
					prometheus.GaugeValue,
					float64(qd.Stats.Bps),
					host,
					ns,
					fmt.Sprintf("%d", interf.Index),
					interf.Attributes.Name,
					qd.Kind,
					fmt.Sprintf("%x:%x", handleMaj, handleMin),
					fmt.Sprintf("%x:%x", parentMaj, parentMin),
				)
				ch <- prometheus.MustNewConstMetric(
					qc.pps,
					prometheus.GaugeValue,
					float64(qd.Stats.Pps),
					host,
					ns,
					fmt.Sprintf("%d", interf.Index),
					interf.Attributes.Name,
					qd.Kind,
					fmt.Sprintf("%x:%x", handleMaj, handleMin),
					fmt.Sprintf("%x:%x", parentMaj, parentMin),
				)
				ch <- prometheus.MustNewConstMetric(
					qc.backlog,
					prometheus.CounterValue,
					float64(qd.Stats.Backlog),
					host,
					ns,
					fmt.Sprintf("%d", interf.Index),
					interf.Attributes.Name,
					qd.Kind,
					fmt.Sprintf("%x:%x", handleMaj, handleMin),
					fmt.Sprintf("%x:%x", parentMaj, parentMin),
				)
				ch <- prometheus.MustNewConstMetric(
					qc.drops,
					prometheus.CounterValue,
					float64(qd.Stats.Drops),
					host,
					ns,
					fmt.Sprintf("%d", interf.Index),
					interf.Attributes.Name,
					qd.Kind,
					fmt.Sprintf("%x:%x", handleMaj, handleMin),
					fmt.Sprintf("%x:%x", parentMaj, parentMin),
				)
				ch <- prometheus.MustNewConstMetric(
					qc.overlimits,
					prometheus.CounterValue,
					float64(qd.Stats.Overlimits),
					host,
					ns,
					fmt.Sprintf("%d", interf.Index),
					interf.Attributes.Name,
					qd.Kind,
					fmt.Sprintf("%x:%x", handleMaj, handleMin),
					fmt.Sprintf("%x:%x", parentMaj, parentMin),
				)
				ch <- prometheus.MustNewConstMetric(
					qc.qlen,
					prometheus.CounterValue,
					float64(qd.Stats.Qlen),
					host,
					ns,
					fmt.Sprintf("%d", interf.Index),
					interf.Attributes.Name,
					qd.Kind,
					fmt.Sprintf("%x:%x", handleMaj, handleMin),
					fmt.Sprintf("%x:%x", parentMaj, parentMin),
				)
			}
		}
	}
}

