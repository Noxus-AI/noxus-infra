{{- define "noxus-platform.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "noxus-platform.fullname" -}}
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

{{- define "noxus-platform.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "noxus-platform.labels" -}}
helm.sh/chart: {{ include "noxus-platform.chart" . }}
{{ include "noxus-platform.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "noxus-platform.selectorLabels" -}}
app.kubernetes.io/name: {{ include "noxus-platform.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "noxus-platform.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "noxus-platform.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{- define "noxus-platform.image" -}}
{{- $registry := .registry | default "" -}}
{{- if $registry -}}
{{- printf "%s/%s:%s" $registry .repository .tag -}}
{{- else -}}
{{- printf "%s:%s" .repository .tag -}}
{{- end -}}
{{- end }}

{{- define "noxus-platform.appEnvSecret" -}}
{{- printf "%s-app-env" (include "noxus-platform.fullname" .) }}
{{- end }}

{{- define "noxus-platform.frontendEnvSecret" -}}
{{- printf "%s-frontend-env" (include "noxus-platform.fullname" .) }}
{{- end }}

{{- define "noxus-platform.relayEnvSecret" -}}
{{- printf "%s-relay-env" (include "noxus-platform.fullname" .) }}
{{- end }}

{{- define "noxus-platform.pgbouncerName" -}}
{{- printf "%s-pgbouncer" (include "noxus-platform.fullname" .) }}
{{- end }}

{{- define "noxus-platform.postgresUrlUser" -}}
{{- $url := regexReplaceAll "^[A-Za-z][A-Za-z0-9+.-]*://" (toString .) "" -}}
{{- if contains "@" $url -}}
{{- $creds := regexReplaceAll "^(.*)@[^@]*$" $url "${1}" -}}
{{- regexReplaceAll "^([^:]*):?.*$" $creds "${1}" -}}
{{- end -}}
{{- end }}

{{- define "noxus-platform.postgresUrlPassword" -}}
{{- $url := regexReplaceAll "^[A-Za-z][A-Za-z0-9+.-]*://" (toString .) "" -}}
{{- if contains "@" $url -}}
{{- $creds := regexReplaceAll "^(.*)@[^@]*$" $url "${1}" -}}
{{- if contains ":" $creds -}}
{{- regexReplaceAll "^[^:]*:(.*)$" $creds "${1}" -}}
{{- end -}}
{{- end -}}
{{- end }}

{{- define "noxus-platform.postgresUrlHost" -}}
{{- $url := regexReplaceAll "^[A-Za-z][A-Za-z0-9+.-]*://" (toString .) "" -}}
{{- if contains "@" $url -}}
{{- $hostPort := regexReplaceAll "^.*@([^/?#]+).*$" $url "${1}" -}}
{{- regexReplaceAll "^([^:]*):?.*$" $hostPort "${1}" -}}
{{- end -}}
{{- end }}

{{- define "noxus-platform.postgresUrlWithHostPort" -}}
{{- $url := regexReplaceAll "^[A-Za-z][A-Za-z0-9+.-]*://" (toString .url) "" -}}
{{- if contains "@" $url -}}
{{- $creds := regexReplaceAll "^(.*)@[^/?#]*.*$" $url "${1}" -}}
{{- printf "%s@%s:%v" $creds .host (.port | int) -}}
{{- end -}}
{{- end }}

{{- define "noxus-platform.secretChecksum" -}}
checksum/secret: {{ include (print $.Template.BasePath "/secrets.yaml") . | sha256sum }}
{{- end }}
