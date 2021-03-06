{{/* vim: set filetype=mustache: */}}

{{/*
Construct the base name for all resources in this chart.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "airflow.fullname" -}}
{{- printf "%s" .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Construct the `labels.app` for used by all resources in this chart.
*/}}
{{- define "airflow.labels.app" -}}
{{- .Values.nameOverride | default .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Construct the `labels.chart` for used by all resources in this chart.
*/}}
{{- define "airflow.labels.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Construct the name of the airflow ServiceAccount.
*/}}
{{- define "airflow.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- .Values.serviceAccount.name | default (include "airflow.fullname" .) -}}
{{- else -}}
{{- .Values.serviceAccount.name | default "default" -}}
{{- end -}}
{{- end -}}

{{/*
Construct the `postgresql.fullname` of the postgresql sub-chat chart.
Used to discover the Service and Secret name created by the sub-chart.
*/}}
{{- define "airflow.postgresql.fullname" -}}
{{- if .Values.postgresql.fullnameOverride -}}
{{- .Values.postgresql.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default "postgresql" .Values.postgresql.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Construct the `redis.fullname` of the redis sub-chat chart.
Used to discover the master Service and Secret name created by the sub-chart.
*/}}
{{- define "airflow.redis.fullname" -}}
{{- if .Values.redis.fullnameOverride -}}
{{- .Values.redis.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default "redis" .Values.redis.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}


{{/*
Construct the AIRFLOW__CORE__SQL_ALCHEMY_CONN connection string.
*/}}
{{- define "airflow.connection.alchemy" -}}
{{- if .Values.postgresql.enabled -}}
postgresql+psycopg2://${DATABASE_USER}:$( python -c "import urllib.parse; encoded_pass = urllib.parse.quote('''${DATABASE_PASSWORD}'''); print(encoded_pass)" )@${DATABASE_HOST}:${DATABASE_PORT}/${DATABASE_DB}
{{- else if and (not .Values.postgresql.enabled) (eq "postgres" .Values.externalDatabase.type) -}}
postgresql+psycopg2://${DATABASE_USER}:$( python -c "import urllib.parse; encoded_pass = urllib.parse.quote('''${DATABASE_PASSWORD}'''); print(encoded_pass)" )@${DATABASE_HOST}:${DATABASE_PORT}/${DATABASE_DB}
{{- else if and (not .Values.postgresql.enabled) (eq "mysql" .Values.externalDatabase.type) -}}
mysqldb+pymysql://${DATABASE_USER}:$( python -c "import urllib.parse; encoded_pass = urllib.parse.quote('''${DATABASE_PASSWORD}'''); print(encoded_pass)" )@${DATABASE_HOST}:${DATABASE_PORT}/${DATABASE_DB}
{{- end -}}
{{- end -}}

{{/*
Construct the AIRFLOW__CELERY__RESULT_BACKEND connection string.
*/}}
{{- define "airflow.connection.celery.backend" -}}
{{- if .Values.postgresql.enabled -}}
db+postgresql://${DATABASE_USER}:$( python -c "import urllib.parse; encoded_pass = urllib.parse.quote('''${DATABASE_PASSWORD}'''); print(encoded_pass)" )@${DATABASE_HOST}:${DATABASE_PORT}/${DATABASE_DB}
{{- else if and (not .Values.postgresql.enabled) (eq "postgres" .Values.externalDatabase.type) -}}
db+postgresql://${DATABASE_USER}:$( python -c "import urllib.parse; encoded_pass = urllib.parse.quote('''${DATABASE_PASSWORD}'''); print(encoded_pass)" )@${DATABASE_HOST}:${DATABASE_PORT}/${DATABASE_DB}
{{- else if and (not .Values.postgresql.enabled) (eq "mysql" .Values.externalDatabase.type) -}}
db+mysql://${DATABASE_USER}:$( python -c "import urllib.parse; encoded_pass = urllib.parse.quote('''${DATABASE_PASSWORD}'''); print(encoded_pass)" )@${DATABASE_HOST}:${DATABASE_PORT}/${DATABASE_DB}
{{- end -}}
{{- end -}}

{{/*
Construct the AIRFLOW__CELERY__BROKER_URL connection string.
Note that a redis URL with no password excludes the "@" prefix.
*/}}
{{- define "airflow.connection.celery.broker" -}}
redis://$( python -c "import urllib.parse; encoded_pass = urllib.parse.quote('''${REDIS_PASSWORD}'''); print(':{}@'.format(encoded_pass)) if len(encoded_pass) > 0 else None" )${REDIS_HOST}:${REDIS_PORT}/${REDIS_DBNUM}
{{- end -}}

{{/*
Construct a set of secret environment variables to be mounted in web, scheduler, worker, and flower pods.
When applicable, we use the secrets created by the postgres/redis charts (which have fixed names and secret keys).
*/}}
{{- define "airflow.mapenvsecrets" -}}
{{- if .Values.postgresql.enabled }}
{{- if .Values.postgresql.existingSecret }}
- name: DATABASE_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ .Values.postgresql.existingSecret }}
      key: {{ .Values.postgresql.existingSecretKey }}
{{- else }}
- name: DATABASE_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "airflow.postgresql.fullname" . }}
      key: postgresql-password
{{- end }}
{{- else }}
- name: DATABASE_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ .Values.externalDatabase.passwordSecret }}
      key: {{ .Values.externalDatabase.passwordSecretKey }}
{{- end }}

{{- if .Values.redis.enabled }}
{{- if .Values.redis.existingSecret }}
- name: REDIS_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ .Values.redis.existingSecret }}
      key: {{ .Values.redis.existingSecretKey }}
{{- else }}
- name: REDIS_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "airflow.redis.fullname" . }}
      key: redis-password
{{- end }}
{{- else }}
- name: REDIS_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ .Values.externalRedis.passwordSecret }}
      key: {{ .Values.externalRedis.passwordSecretKey }}
{{- end }}
{{- if .Values.airflow.extraEnv }}
{{ toYaml .Values.airflow.extraEnv }}
{{- end }}

{{- end -}}
