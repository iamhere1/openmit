#include <unistd.h>
#include "dmlc/logging.h"
#include "dmlc/timer.h"
#include "rabit/rabit.h"
#include "openmit/framework/mpi/mpi_admm.h"
#include "openmit/tools/monitor/transaction.h"

namespace mit {

MPIAdmm::MPIAdmm(const mit::KWArgs& kwargs) {
  rabit::Init(0, nullptr);
  admm_param_.InitAllowUnknown(kwargs);
  cli_param_.InitAllowUnknown(kwargs);
  mpi_worker_.reset(new MPIWorker(kwargs));
  mpi_server_.reset(new MPIServer(kwargs, mpi_worker_->Size()));
}

void MPIAdmm::Run() {
  double startTime = dmlc::GetTime();
  if (cli_param_.task_type == "train") {
    RunTrain();
  } else if (cli_param_.task_type == "predict") {
    RunPredict();
  } else {
    LOG(ERROR) << "unknown 'task_type' task: " << cli_param_.task_type;
  }
  double endTime = dmlc::GetTime();
  rabit::TrackerPrintf("@worker[%d] [OpenMIT-MPI] \
      The total time of the task %s is %g s \n", 
      rabit::GetRank(), cli_param_.task_type.c_str(), endTime-startTime);

  rabit::Finalize();
}

void MPIAdmm::RunTrain() {
  for (auto iter = 0u; iter < cli_param_.max_epoch; ++iter) {
    // learning 
    mpi_worker_->Run(mpi_server_->Data(), mpi_server_->Size(), iter + 1);
    mpi_server_->Run(mpi_worker_->Data(), mpi_worker_->Dual(), mpi_worker_->Size());
    mpi_worker_->UpdateDual(mpi_server_->Data(), mpi_server_->Size());
    
    if (cli_param_.debug) { 
      mpi_worker_->Debug(); mpi_server_->DebugTheta();
    }
    // metric 
    std::string metric_train = mpi_worker_->Metric(
      std::string("train"), mpi_server_->Data(), mpi_server_->Size());
    std::string metric_valid = mpi_worker_->Metric(
      std::string("valid"), mpi_server_->Data(), mpi_server_->Size());

    if (rabit::GetRank() == rabit::GetWorldSize() - 1) {
      rabit::TrackerPrintf("finished %d-th epoch. [train] %s\t[valid] %s", 
                           iter + 1, metric_train.c_str(), metric_valid.c_str());
    }
  }
  if (rabit::GetRank() == 0) {
    std::string dump_out = cli_param_.out_path + "/model_dump";
    std::unique_ptr<dmlc::Stream> fo(
      dmlc::Stream::Create(dump_out.c_str(), "w"));
    mpi_server_->SaveModel(fo.get());
  }
}

void MPIAdmm::RunPredict() {
  LOG(INFO) << "MPIAdmm::RunPredict() ...";
}

} // namespace mit
