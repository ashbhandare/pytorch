#include <ATen/Dispatch.h>
#include <ATen/native/ForeachUtils.h>
#include <ATen/native/cuda/ForeachFunctors.cuh>

namespace at { namespace native {

template <template<class> class Op>
std::vector<Tensor> foreach_unary_op(TensorList tensors) {
    std::vector<std::vector<at::Tensor>> tensor_lists;
    std::vector<at::Tensor> vec_res;
    vec_res.reserve(tensors.size());
    for (const auto& t: tensors) {
        vec_res.emplace_back(at::native::empty_like(t));
    }

    tensor_lists.emplace_back(tensors.vec());
    tensor_lists.emplace_back(std::move(vec_res));

    AT_DISPATCH_FLOATING_AND_COMPLEX_TYPES_AND1(ScalarType::Half,  tensors[0].scalar_type(), "foreach_unary_op_cuda", [&]() {
        using opmath_t = get_opmath_t<scalar_t>::opmath_t;
        multi_tensor_apply<2>(tensor_lists,
                              UnaryOpFunctor<scalar_t>(),
                              Op<opmath_t>());
    });
    return tensor_lists[1];
}

template <template<class> class Op>
void foreach_unary_op_(TensorList tensors) {
    std::vector<std::vector<at::Tensor>> tensor_lists;
    tensor_lists.emplace_back(tensors.vec());

    AT_DISPATCH_FLOATING_AND_COMPLEX_TYPES_AND1(ScalarType::Half, tensors[0].scalar_type(), "foreach_unary_op_cuda_", [&]() {
        using opmath_t = get_opmath_t<scalar_t>::opmath_t;
        multi_tensor_apply<1>(tensor_lists,
                              UnaryOpFunctor_<scalar_t>(),
                              Op<opmath_t>());
    });
}

#define FOREACH_UNARY_OP(NAME, NAME1)                                   \
template<typename T>                                                    \
struct NAME1 {                                                          \
    __device__ T operator()(T t) const { return std::NAME(t); }         \
};                                                                      \
                                                                        \
std::vector<Tensor> foreach_tensor_##NAME##_cuda(TensorList tensors) {  \
    check_foreach_api_restrictions(tensors);                            \
                                                                        \
    if (!can_use_fast_route(tensors)) {                                 \
        return at::native::foreach_tensor_##NAME##_slow(tensors);       \
    }                                                                   \
                                                                        \
    return foreach_unary_op<NAME1>(tensors);                            \
}                                                                       \
                                                                        \
void foreach_tensor_##NAME##_cuda_(TensorList tensors) {                \
    check_foreach_api_restrictions(tensors);                            \
                                                                        \
    if (!can_use_fast_route(tensors)) {                                 \
        return at::native::foreach_tensor_##NAME##_slow_(tensors);      \
    }                                                                   \
                                                                        \
    foreach_unary_op_<NAME1>(tensors);                                  \
}

FOREACH_UNARY_OP(exp, Exp);
FOREACH_UNARY_OP(sqrt, Sqrt);

void foreach_tensor_zero_cuda_(TensorList tensors) {
    check_foreach_api_restrictions(tensors);

    if (!can_use_fast_route(tensors)) {
        return at::native::foreach_tensor_zero_slow_(tensors);
    }

    std::vector<std::vector<at::Tensor>> tensor_lists;
    tensor_lists.emplace_back(tensors.vec());

    AT_DISPATCH_FLOATING_AND_COMPLEX_TYPES_AND1(ScalarType::Half, tensors[0].scalar_type(), "foreach_zero_cuda_", [&]() {
        multi_tensor_apply<1>(tensor_lists,
                              ZeroFunctor_<scalar_t>());
    });
}

}} // namespace at::native
