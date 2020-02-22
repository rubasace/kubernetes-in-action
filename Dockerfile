FROM google/cloud-sdk:latest

#Dependencies
RUN apt-get install -y vim nano watch pkg-config bash-completion

#Kubectl autocompletion
RUN echo 'source /usr/share/bash-completion/bash_completion' >> ~/.bashrc && \
    echo 'source <(kubectl completion bash)' >> ~/.bashrc


ADD  https://raw.githubusercontent.com/ahmetb/kubectx/master/kubectx /usr/local/bin/
ADD  https://raw.githubusercontent.com/ahmetb/kubectx/master/kubens /usr/local/bin/
RUN  chmod +x /usr/local/bin/kubens /usr/local/bin/kubectx

RUN git clone https://github.com/ahmetb/kubectx.git ~/.kubectx && \
    COMPDIR=$(pkg-config --variable=completionsdir bash-completion) && \
    ln -sf ~/.kubectx/completion/kubens.bash $COMPDIR/kubens && \
    ln -sf ~/.kubectx/completion/kubectx.bash $COMPDIR/kubectx && \
    echo "export PATH=~/.kubectx:\$PATH" ~/.bashrc

ENV KUBE_EDITOR="/bin/nano"

CMD bash