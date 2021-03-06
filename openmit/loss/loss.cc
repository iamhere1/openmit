#include "openmit/loss/loss.h"

namespace mit {
Loss * Loss::Create(std::string type) {
  if (type == "squared") {
    LOG(INFO)<<"loss:squared";
    return new Loss(SquaredLoss::LossFunc, SquaredLoss::Gradient);
  } else if (type == "logit") {
    LOG(INFO)<<"loss:logit";
    return new Loss(LogitLoss::LossFunc, LogitLoss::Gradient);
  } else {
    LOG(FATAL) << "type of loss: " << type << " not recognized.";
    return nullptr;
  }
}

} // namespace mit
