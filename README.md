# Fazendo setup da infraestrutura com AWS Academy

1. Inicie o laboratório de aprendizagem;
2. Copie as informações de credenciamento da sessão e utilize na sua máquina local (aws_access_key_id, aws_secret_access_key e AWS_SESSION_TOKEN). Você pode utilizar essas configurações através do `aws configure` ou definindo as variáveis de ambiente na sua máquina;
3. Utilize os comandos `terraform init`, `terraform validate`, `terraform plan -no-color -out=tfplan` e `terraform apply -no-color -auto-approve tfplan`.

Caso o provisionamento tenha sido executado com sucesso, basta usufruir. Mas caso tenha dado errado, utilize o seguinte comando para "desprovisionar" o que foi feito:

4. `terraform destroy -auto-approve`.
