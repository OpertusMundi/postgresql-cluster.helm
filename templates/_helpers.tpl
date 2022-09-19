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
app.kubernetes.io/component: server
postgresql-cluster.opertusmundi.github.io/tier: backend
{{- end }}

{{/* Selector labels for master Pod */}}
{{- define "postgresql-cluster.selectorLabelsForMaster" -}}
{{ include "postgresql-cluster.selectorLabelsForBackend" . }}
postgresql-cluster.opertusmundi.github.io/master: ""
{{- end }}

{{- define "postgresql-cluster.labelsForMaster" }}
{{ include "postgresql-cluster.labels" . }}
postgresql-cluster.opertusmundi.github.io/master: ""
{{- end }}

{{- define "postgresql-cluster.labelsForStandby" }}
{{ include "postgresql-cluster.labels" . }}
postgresql-cluster.opertusmundi.github.io/standby: ""
{{- end }}

{{- define "postgresql-cluster.labelsForPgpool" }}
{{ include "postgresql-cluster.labels" . }}
postgresql-cluster.opertusmundi.github.io/pgpool: ""
{{- end }}

{{/* Selector labels for standby Pod(s) */}}
{{- define "postgresql-cluster.selectorLabelsForStandby" -}}
{{ include "postgresql-cluster.selectorLabelsForBackend" . }}
postgresql-cluster.opertusmundi.github.io/standby: ""
{{- end }}

{{/* Selector labels for PgPool Pod(s) */}}
{{- define "postgresql-cluster.selectorLabelsForPgpool" -}}
{{ include "postgresql-cluster.selectorLabels" . }}
app.kubernetes.io/component: server
postgresql-cluster.opertusmundi.github.io/tier: proxy
postgresql-cluster.opertusmundi.github.io/pgpool: ""
{{- end }}

{{/* Selector labels for exec Pod (psql) */}}
{{- define "postgresql-cluster.selectorLabelsForCommandLine" -}}
{{ include "postgresql-cluster.selectorLabels" . }}
app.kubernetes.io/component: cli
{{- end }}

{{- define "postgresql-cluster.postgres.standbyNames" -}}
{{- $fullname := (include "postgresql-cluster.fullname" .) -}}
{{- range $i := (until (.Values.postgres.replicas | int)) -}}
{{- if gt $i 0 }}{{ print "," }}{{ end }}{{ printf "%s_standby_%d" ($fullname | replace "-" "_") $i -}}
{{- end }}{{/* range */}}
{{- end }}

{{- define "postgresql-cluster.postgres.synchronousStandbyNames" -}}
{{- $fullname := (include "postgresql-cluster.fullname" .) -}}
{{- range $i := (until (.Values.postgres.replicasToSync | int)) -}}
{{- if gt $i 0 }}{{ print "," }}{{ end }}{{ printf "%s_standby_%d" ($fullname | replace "-" "_") $i -}}
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
{{ .Values.postgresPassword.secretName | default (printf "%s-postgres-password" (include "postgresql-cluster.fullname" .)) }}
{{- end }}

{{- define "postgresql-cluster.replicationPassword.secretName" -}}
{{ .Values.replicationPassword.secretName | default (printf "%s-replication-password" (include "postgresql-cluster.fullname" .)) }}
{{- end }}

{{- define "postgresql-cluster.monitorPassword.secretName" -}}
{{ .Values.monitorPassword.secretName | default (printf "%s-monitor-password" (include "postgresql-cluster.fullname" .)) }}
{{- end }}

{{- define "postgresql-cluster.pgpoolAdminPassword.secretName" -}}
{{ .Values.pgpoolAdminPassword.secretName | default (printf "%s-pgpool-admin-password" (include "postgresql-cluster.fullname" .)) }}
{{- end }}

{{- define "postgresql-cluster.userPasswords.secretName" -}}
{{ .Values.userPasswords.secretName | default (printf "%s-user-passwords" (include "postgresql-cluster.fullname" .)) }}
{{- end }}

{{- define "postgresql-cluster.tls.secretName" -}}
{{ .Values.tls.secretName | default (printf "%s-postgres-tls" (include "postgresql-cluster.fullname" .)) }} 
{{- end }}

{{- define "postgresql-cluster.postgres.serviceName" -}}
{{ .Values.postgres.serviceName | default (include "postgresql-cluster.fullname" .) }} 
{{- end }}

{{- define "postgresql-cluster.clusterDomain" -}}
{{ printf "%s.svc.cluster.local" .Release.Namespace }}
{{- end }}

{{- define "postgresql-cluster.postgres.serviceDomain" -}}
{{- $clusterDomain := (include "postgresql-cluster.clusterDomain" .) -}}
{{- $serviceName := (include "postgresql-cluster.postgres.serviceName" .) -}}
{{ printf "%s.%s" $serviceName $clusterDomain }} 
{{- end }}

{{- define "postgresql-cluster.postgres.archivePvcName" -}}
{{ printf "archive-%s" (include "postgresql-cluster.fullname" .) }} 
{{- end }}


{{/* 
Generate contents of pgpass file 
*/}}
{{- define "postgresql-cluster.pgpass" -}}

{{- $fullname := (include "postgresql-cluster.fullname" .) -}}
{{- $clusterDomain := (include "postgresql-cluster.clusterDomain" .) -}}
{{- $serviceName := (include "postgresql-cluster.postgres.serviceName" .) -}}
{{- $serviceDomain := (include "postgresql-cluster.postgres.serviceDomain" .) -}}

{{- $postgresPasswordSecret := (lookup "v1" "Secret" .Release.Namespace .Values.postgresPassword.secretName) -}}
{{- if $postgresPasswordSecret }}
{{- $postgresPassword := ((get $postgresPasswordSecret "data").password) | b64dec }}
{{ printf "%s-master-0.%s:5432:*:postgres:%s" $fullname $serviceDomain $postgresPassword }}
{{ range $i := until (int $.Values.postgres.replicas) }}
{{- printf "%s-standby-%d.%s:5432:*:postgres:%s" $fullname $i $serviceDomain $postgresPassword }}
{{ end }}{{/* range $i */}}
{{- end -}}{{/* if $postgresPasswordSecret */}}

{{- $userPasswordsSecret := (lookup "v1" "Secret" .Release.Namespace .Values.userPasswords.secretName) }}
{{- if $userPasswordsSecret }}
{{ range $username := keys (get $userPasswordsSecret "data") }}
{{- $password := (get (get $userPasswordsSecret "data") $username) | b64dec }}
{{- printf "%s-master-0.%s:5432:*:%s:%s" $fullname $serviceDomain $username $password }}
{{ range $i := until (int $.Values.postgres.replicas) }}
{{- printf "%s-standby-%d.%s:5432:*:%s:%s" $fullname $i $serviceDomain $username $password }}
{{ end -}}{{/* range $i */}}
{{- if $.Values.pgpool.enabled }}
{{- printf "%s-pgpool.%s:5433:*:%s:%s" $serviceName $clusterDomain $username $password }}
{{ end }}{{/* if $.Values.pgpool.enabled */}}
{{ end }}{{/* range $username */}}
{{- end }}{{/* if $userPasswordsSecret */}}

{{- end }}{{/* define */}}

