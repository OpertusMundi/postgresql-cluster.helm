{{/* vim: set filetype=helm: */}}

{{/*
Expand the name of the chart.
*/}}
{{- define "postgresql-cluster.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "postgresql-cluster.fullname" -}}
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

{{/* Create chart name and version as used by the chart label. */}}
{{- define "postgresql-cluster.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/* Common labels */}}
{{- define "postgresql-cluster.labels" -}}
helm.sh/chart: {{ include "postgresql-cluster.chart" . }}
{{ include "postgresql-cluster.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/* Common selector labels */}}
{{- define "postgresql-cluster.selectorLabels" -}}
app.kubernetes.io/name: {{ include "postgresql-cluster.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/* Selector labels for master Pod */}}
{{- define "postgresql-cluster.selectorLabelsForMaster" -}}
{{ include "postgresql-cluster.selectorLabels" . }}
role-in-database-cluster: master
{{- end }}

{{/* Selector labels for standby Pod(s) */}}
{{- define "postgresql-cluster.selectorLabelsForStandby" -}}
{{ include "postgresql-cluster.selectorLabels" . }}
role-in-database-cluster: standby
{{- end }}

{{/* Create the name of the service account to use */}}
{{- define "postgresql-cluster.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "postgresql-cluster.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{- define "postgresql-cluster.postgresPassword.secretName" -}}
{{ .Values.postgresPassword.secretName | default (printf "%s-postgres-password" .Release.Name) }}
{{- end }}

{{- define "postgresql-cluster.replicationPassword.secretName" -}}
{{ .Values.replicationPassword.secretName | default (printf "%s-replication-password" .Release.Name) }}
{{- end }}

{{- define "postgresql-cluster.monitorPassword.secretName" -}}
{{ .Values.monitorPassword.secretName | default (printf "%s-monitor-password" .Release.Name) }}
{{- end }}

{{- define "postgresql-cluster.userPasswords.secretName" -}}
{{ .Values.userPasswords.secretName | default (printf "%s-user-passwords" .Release.Name) }}
{{- end }}

{{- define "postgresql-cluster.postgres.tls.secretName" -}}
{{ .Values.postgres.tls.secretName | default (printf "%s-postgres-tls" .Release.Name) }} 
{{- end }}

{{- define "postgresql-cluster.postgres.command" -}}
[ 
  'postgres', '-c', 'config_file=$(CONFIG_FILE)',
  '-c', 'ssl_key_file=$(TLS_KEY_FILE)', '-c', 'ssl_cert_file=$(TLS_CERT_FILE)',
  '-c', 'max_connections={{ .maxNumberOfConnections | default 128 }}' 
]
{{- end }}

{{- define "postgresql-cluster.postgres.readinessCommand" -}}
[
  'su-exec', 'postgres',
  'pg_isready', '-h', 'localhost'
]
{{- end }}

