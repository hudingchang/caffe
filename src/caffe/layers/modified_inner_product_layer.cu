#include <vector>

#include "caffe/filler.hpp"
#include "caffe/layers/modified_inner_product_layer.hpp"
#include "caffe/util/math_functions.hpp"

namespace caffe {

template <typename Dtype>
void ModifiedInnerProductLayer<Dtype>::Forward_gpu(const vector<Blob<Dtype>*>& bottom,
    const vector<Blob<Dtype>*>& top) {
  const Dtype* bottom_data = bottom[0]->gpu_data();
  Dtype* top_data = top[0]->mutable_gpu_data();
  const Dtype* weight = this->blobs_[0]->gpu_data();
  if (this->M_ == 1) {
    caffe_gpu_gemv<Dtype>(CblasNoTrans, this->N_, this->K_, (Dtype)1.,
                         weight, bottom_data, (Dtype)0., top_data);
    if (this->bias_term_)
      caffe_gpu_axpy<Dtype>(N_, bias_multiplier_.cpu_data()[0],
                            this->blobs_[1]->gpu_data(), top_data);
  } else {
    caffe_gpu_gemm<Dtype>(CblasNoTrans,
                          transpose_ ? CblasNoTrans : CblasTrans,
                          this->M_, this->N_, this->K_, (Dtype)1.,
                          bottom_data, weight, (Dtype)0., top_data);
    if (this->bias_term_)
      caffe_gpu_gemm<Dtype>(CblasNoTrans, CblasNoTrans, this->M_, this->N_, 1, (Dtype)1.,
                            this->bias_multiplier_.gpu_data(),
                            this->blobs_[1]->gpu_data(), (Dtype)1., top_data);
  }
}

template <typename Dtype>
void ModifiedInnerProductLayer<Dtype>::Backward_gpu(const vector<Blob<Dtype>*>& top,
    const vector<bool>& propagate_down,
    const vector<Blob<Dtype>*>& bottom) {
  if (this->param_propagate_down_[0]) {
    const Dtype* top_diff = top[0]->gpu_diff();
    const Dtype* bottom_data = bottom[0]->gpu_data();
    // Gradient with respect to weight
    if (this->transpose_) {
      caffe_gpu_gemm<Dtype>(CblasTrans, CblasNoTrans,
          this->K_, this->N_, this->M_,
          (Dtype)1., bottom_data, top_diff,
          (Dtype)1., this->blobs_[0]->mutable_gpu_diff());
    } else {
      caffe_gpu_gemm<Dtype>(CblasTrans, CblasNoTrans,
          this->N_, this->K_, this->M_,
          (Dtype)1., top_diff, bottom_data,
          (Dtype)1., this->blobs_[0]->mutable_gpu_diff());
    }
    // Added by Wang
    if (this->output_weight_) {
      caffe_gpu_axpy<Dtype>(this->blobs_[0]->count(), this->alpha_, 
        top[1]->gpu_diff(), this->blobs_[0]->mutable_gpu_diff());
    }
  }
  if (this->bias_term_ && this->param_propagate_down_[1]) {
    const Dtype* top_diff = top[0]->gpu_diff();
    // Gradient with respect to bias
    caffe_gpu_gemv<Dtype>(CblasTrans, this->M_, this->N_, (Dtype)1., top_diff,
        this->bias_multiplier_.gpu_data(), (Dtype)1.,
        this->blobs_[1]->mutable_gpu_diff());
  }
  if (propagate_down[0]) {
    const Dtype* top_diff = top[0]->gpu_diff();
    // Gradient with respect to bottom data
    if (this->transpose_) {
      caffe_gpu_gemm<Dtype>(CblasNoTrans, CblasTrans,
          this->M_, this->K_, this->N_,
          (Dtype)1., top_diff, this->blobs_[0]->gpu_data(),
          (Dtype)0., bottom[0]->mutable_gpu_diff());
    } else {
      caffe_gpu_gemm<Dtype>(CblasNoTrans, CblasNoTrans,
          this->M_, this->K_, this->N_,
         (Dtype)1., top_diff, this->blobs_[0]->gpu_data(),
         (Dtype)0., bottom[0]->mutable_gpu_diff());
    }
  }
}

INSTANTIATE_LAYER_GPU_FUNCS(ModifiedInnerProductLayer);

}  // namespace caffe