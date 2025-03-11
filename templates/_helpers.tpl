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

{{/* Common labels for managed resources */}}
{{- define "postgresql-cluster.labels" -}}
helm.sh/chart: {{ include "postgresql-cluster.chart" . }}
{{ include "postgresql-cluster.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/* Common labels for hook resources */}}
{{- define "postgresql-cluster.hookLabels" -}}
app.kubernetes.io/name: {{ include "postgresql-cluster.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
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

{{/* Selector labels for master data PV  */}}
{{- define "postgresql-cluster.selectorLabelsForMasterData" -}}
{{ include "postgresql-cluster.selectorLabels" . }}
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

{{/* Selector labels for standby data PV  */}}
{{- define "postgresql-cluster.selectorLabelsForStandbyData" -}}
{{ include "postgresql-cluster.selectorLabels" . }}
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

{{- define "postgresql-cluster.postgres.configurationStanzaForReplicationInStandby" -}}
{{- $fullname := (include "postgresql-cluster.fullname" .) -}}
{{- $serviceDomain := (include "postgresql-cluster.postgres.serviceDomain" .) -}}
{{- $masterHost := (printf "%s-master-0.%s" $fullname $serviceDomain) -}}
include_if_exists = '/var/lib/postgresql/data/01-cluster-name.conf'
primary_conninfo = {{ printf "user=replicator host=%s port=5432 sslmode=prefer sslcompression=0" $masterHost | squote }}
restore_command = 'cp -v /var/backups/postgresql/archive-master/%f %p'
promote_trigger_file = 'trigger-failover'
recovery_target_timeline = 'latest'
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

{{/* Annotations for generated passwords */}}
{{- define "postgresql-cluster.hookAnnotationsForPassword" -}}
helm.sh/hook: pre-install
helm.sh/hook-weight: "-3"
helm.sh/hook-delete-policy: hook-failed
{{- end }}{{/* define */}}

{{- define "postgresql-cluster.postgres.pvcTemplateForMasterData" -}}
{{- with .Values.postgres.pv.dataDir }}
metadata:
  name: data
spec:
  accessModes: 
  - ReadWriteOnce
  storageClassName: {{ .storageClassName }}
  resources:
    requests:
      storage: {{ .size }}
  {{- if .useSelector }}
  selector:
    matchLabels:
      {{- include "postgresql-cluster.selectorLabelsForMasterData" $ | nindent 10 }}  
      {{- if .extraMatchLabels }}{{ toYaml .extraMatchLabels | nindent 10 }}{{- end }}
  {{- end }}{{/* if .useSelector */}}
{{- end }}{{/* with .Values.postgres.pv.dataDir */}}
{{- end }}

{{- define "postgresql-cluster.postgres.pvcTemplateForStandbyData" -}}
{{- with .Values.postgres.pv.dataDir }}
metadata:
  name: data
spec:
  accessModes: 
  - ReadWriteOnce
  storageClassName: {{ .storageClassName }}
  resources:
    requests:
      storage: {{ .size }}
  {{- if .useSelector }}
  selector:
    matchLabels:
      {{- include "postgresql-cluster.selectorLabelsForStandbyData" $ | nindent 10 }}  
      {{- if .extraMatchLabels }}{{ toYaml .extraMatchLabels | nindent 10 }}{{- end }}
  {{- end }}{{/* if .useSelector */}}
{{- end }}{{/* with .Values.postgres.pv.dataDir */}}
{{- end }}

{{- define "postgresql-cluster.postgres.pvcTemplateForLogs" -}}
{{- with .Values.postgres.pv.logsDir }}
metadata:
  name: logs
spec:
  accessModes: 
  - ReadWriteOnce
  storageClassName: {{ .storageClassName }}
  resources:
    requests:
      storage: {{ .size }}
  {{- if .useSelector }}
  selector:
    matchLabels:
      {{- if .extraMatchLabels }}{{ toYaml .extraMatchLabels | nindent 10 }}{{- end }}
  {{- end }}{{/* if .useSelector */}}
{{- end }}{{/* with .Values.postgres.pv.logsDir */}}
{{- end }}


{{- define "postgresql-cluster.postgres.containerForLogs" -}}
name: tail
image: busybox:1
securityContext:
  runAsUser: {{ .Values.postgres.securityContext.uid }}
stdin: true
workingDir: /tmp
command:
- sh
- -eu
- -c
- |-
  cp /var/lib/postgresql/data/current_logfiles .
  logfile=$(awk '/^stderr\s/{print $2}' current_logfiles)
  tail -v -n +1 -F ${logfile}
livenessProbe:
  exec:
    command:
    - diff
    - -q
    - /tmp/current_logfiles
    - /var/lib/postgresql/data/current_logfiles
  initialDelaySeconds: 18
  periodSeconds: 6
resources:
  limits:
    memory: 128Mi
  requests:
    memory: 32Mi
volumeMounts:
- name: data
  mountPath: /var/lib/postgresql/data
  subPath: {{ .Values.postgres.pv.dataDir.subPath }}
  readOnly: true
{{- if .Values.postgres.pv.logsDir }}
- name: logs
  mountPath: /var/lib/postgresql/logs
  readOnly: true
{{- end }}{{/* if .Values.postgres.pv.logsDir */}}
{{- end }}
