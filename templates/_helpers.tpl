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

{{/* Selector labels for master/standby database Pods (backend) */}}
{{- define "postgresql-cluster.selectorLabelsForBackend" -}}
{{ include "postgresql-cluster.selectorLabels" . }}
tier-in-database-cluster: backend
{{- end }}

{{/* Selector labels for master Pod */}}
{{- define "postgresql-cluster.selectorLabelsForMaster" -}}
{{ include "postgresql-cluster.selectorLabelsForBackend" . }}
backend-role: master
{{- end }}

{{/* Selector labels for standby Pod(s) */}}
{{- define "postgresql-cluster.selectorLabelsForStandby" -}}
{{ include "postgresql-cluster.selectorLabelsForBackend" . }}
backend-role: standby
{{- end }}

{{/* Selector labels for PgPool Pod(s) */}}
{{- define "postgresql-cluster.selectorLabelsForPgpool" -}}
{{ include "postgresql-cluster.selectorLabels" . }}
tier-in-database-cluster: proxy
{{- end }}

{{- define "postgresql-cluster.postgres.standbyNames" -}}
{{- range $i := (until (.Values.postgres.replicas | int)) -}}
{{- if gt $i 0 }}{{ print "," }}{{ end }}{{ printf "%s_standby_%d" ($.Release.Name | replace "-" "_") $i -}}
{{- end }}{{/* range */}}
{{- end }}

{{- define "postgresql-cluster.postgres.synchronousStandbyNames" -}}
{{- range $i := (until (.Values.postgres.replicasToSync | int)) -}}
{{- if gt $i 0 }}{{ print "," }}{{ end }}{{ printf "%s_standby_%d" ($.Release.Name | replace "-" "_") $i -}}
{{- end }}{{/* range */}}
{{- end }}

{{- define "postgresql-cluster.postgres.configurationStanzaForReplicationInMaster" -}}
{{- $replicas := .Values.postgres.replicas | int -}}
{{- $replicasToSync := .Values.postgres.replicasToSync | int -}}
{{- if gt $replicasToSync $replicas }}
{{- fail "The number of synchronous standbys must be less than or equal to number of replicas" -}}
{{- else if gt $replicasToSync 0 -}}
synchronous_commit = remote_apply
synchronous_standby_names = {{ printf "FIRST %d (%s)" $replicasToSync (include "postgresql-cluster.postgres.synchronousStandbyNames" .) | squote }}
{{- end -}}{{/*if*/}}
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

{{- define "postgresql-cluster.pgpoolAdminPassword.secretName" -}}
{{ .Values.pgpoolAdminPassword.secretName | default (printf "%s-pgpool-admin-password" .Release.Name) }}
{{- end }}

{{- define "postgresql-cluster.userPasswords.secretName" -}}
{{ .Values.userPasswords.secretName | default (printf "%s-user-passwords" .Release.Name) }}
{{- end }}

{{- define "postgresql-cluster.tls.secretName" -}}
{{ .Values.tls.secretName | default (printf "%s-postgres-tls" .Release.Name) }} 
{{- end }}

{{- define "postgresql-cluster.postgres.serviceName" -}}
{{ .Values.postgres.serviceName | default .Release.Name }} 
{{- end }}

{{- define "postgresql-cluster.pgpool.serviceName" -}}
{{ .Values.postgres.serviceName | default (printf "%s-pgpool" .Release.Name) }} 
{{- end }}

{{- define "postgresql-cluster.postgres.archivePvcName" -}}
{{ printf "archive-%s" .Release.Name }} 
{{- end }}

