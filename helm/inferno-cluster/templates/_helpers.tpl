{{/*
Expand the name of the chart.
*/}}
{{- define "inferno-cluster.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "inferno-cluster.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version for chart label.
*/}}
{{- define "inferno-cluster.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "inferno-cluster.labels" -}}
helm.sh/chart: {{ include "inferno-cluster.chart" . }}
{{ include "inferno-cluster.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: inferno-cluster
{{- end }}

{{/*
Selector labels
*/}}
{{- define "inferno-cluster.selectorLabels" -}}
app.kubernetes.io/name: {{ include "inferno-cluster.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Registry labels
*/}}
{{- define "inferno-cluster.registryLabels" -}}
{{ include "inferno-cluster.labels" . }}
app.kubernetes.io/component: registry
{{- end }}

{{/*
Registry selector labels
*/}}
{{- define "inferno-cluster.registrySelectorLabels" -}}
{{ include "inferno-cluster.selectorLabels" . }}
app.kubernetes.io/component: registry
{{- end }}

{{/*
CPU pool labels
*/}}
{{- define "inferno-cluster.cpupoolLabels" -}}
{{ include "inferno-cluster.labels" . }}
app.kubernetes.io/component: cpupool
{{- end }}

{{/*
CPU pool selector labels
*/}}
{{- define "inferno-cluster.cpupoolSelectorLabels" -}}
{{ include "inferno-cluster.selectorLabels" . }}
app.kubernetes.io/component: cpupool
{{- end }}

{{/*
Emulator labels
*/}}
{{- define "inferno-cluster.emulatorLabels" -}}
{{ include "inferno-cluster.labels" . }}
app.kubernetes.io/component: emulator
{{- end }}

{{/*
Emulator selector labels
*/}}
{{- define "inferno-cluster.emulatorSelectorLabels" -}}
{{ include "inferno-cluster.selectorLabels" . }}
app.kubernetes.io/component: emulator
{{- end }}

{{/*
Image specification
*/}}
{{- define "inferno-cluster.image" -}}
{{ .Values.global.image.repository }}:{{ .Values.global.image.tag | default .Chart.AppVersion }}
{{- end }}

{{/*
Prometheus annotations
*/}}
{{- define "inferno-cluster.prometheusAnnotations" -}}
{{- if .Values.monitoring.prometheusAnnotations }}
prometheus.io/scrape: "true"
prometheus.io/port: {{ .Values.monitoring.metricsPort | quote }}
{{- end }}
{{- end }}
